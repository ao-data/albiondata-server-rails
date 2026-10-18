# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is the Rails backend for the Albion Online Data Project (AODP). It ingests real-time market
order, gold price, and market history submissions from third-party Albion Online client trackers
over NATS, deduplicates them, persists them to region-sharded MySQL/MariaDB databases, and serves
that data back out through a small JSON API.

## Further documentation

- [Testing](docs/testing.md) — building the Docker image, running the test suite, running a single spec
- [Git workflow](docs/git.md) — branching, committing, and merge/push rules for this repo

## Architecture

### Everything is sharded by region: west / east / europe

Albion Online runs separate game servers per region, and this app keeps a fully independent stack
per region rather than a `region` column:

- **MySQL**: `config/database.yml` defines a `multidb` block with `west`/`east`/`europe` entries
  (backed by `MYSQL_WEST_URL`/`MYSQL_EAST_URL`/`MYSQL_EUROPE_URL`). The `ar-multidb` gem provides
  `Multidb.use(server_id.to_sym) { ... }` to switch the ActiveRecord connection for the block.
  Services/workers that touch the DB call `Multidb.use` in `initialize` (or wrap the DB call in a
  block) using the `server_id` they were handed — see `app/services/market_order_processor_service.rb`
  and `app/workers/market_history_cleanup_worker.rb`.
- **Redis**: `config/initializers/redis.rb` builds a `REDIS` hash keyed by region string
  (`REDIS['west']`, `REDIS['east']`, `REDIS['europe']`), plus a separate `REDIS['identifier']`
  instance for request-tracing (see below). This is distinct from the Sidekiq Redis
  (`SIDEKIQ_REDIS_URL`) and the Rack::Attack Redis (`RACKATTACK_REDIS_URL`).
- **NATS**: one NATS server per region (`NATS_WEST_URL`/`NATS_EAST_URL`/`NATS_EUROPE_URL`).
- **Migrations**: `rake aodp:db:migrate` (`lib/tasks/db.rake`) loops over all three regions and
  runs `db:migrate` inside `Multidb.use(server)` for each.

### Ingestion pipeline

Client trackers publish directly to NATS; this app does not expose an HTTP ingest endpoint for
market data. The flow for market orders (gold prices and market history mirror this):

1. A container running `RUN_MODE=nats` calls `NatsService#listen` (via rake tasks
   `aodp:nats:subscribe_west`/`_east`/`_europe` in `lib/tasks/nats_subscribe.rake`), which
   subscribes to `marketorders.ingest` / `goldprices.ingest` / `markethistories.ingest`.
2. Each message is handed off to a thin Sidekiq dedupe worker
   (`MarketOrderDedupeWorker`/`GoldDedupeWorker`/`MarketHistoryDedupeWorker`), which just parses
   JSON args and delegates to the matching `*DedupeService`.
3. The dedupe service (`app/services/market_order_dedupe_service.rb` etc.) re-publishes the raw
   batch to NATS, hashes each record (SHA256) and checks/sets it in the region's Redis with a TTL
   to drop duplicates, republishes the deduped batch to NATS (`*.deduped`, `*.deduped.bulk`), emits
   an `ActiveSupport::Notifications` metrics event, and hands the deduped records to a
   `*ProcessorWorker`.
4. The processor worker delegates to a `*ProcessorService`, which calls `Multidb.use(server_id)`
   and does the actual `upsert_all`/insert into the region's database.

**Pattern**: workers (`app/workers/`) are always thin `Sidekiq::Job` wrappers — they parse the
JSON args and immediately delegate to a same-named service in `app/services/`. Business logic
lives in the services, not the workers.

### Request tracing via "identifier"

Clients can pass an `identifier` (in `opts`) through the pipeline. `IdentifierService` appends a
JSON event to `REDIS['identifier']` at each pipeline stage (received, deduped, saved, ...) keyed by
`IDENTIFIER:<server>:<identifier>`, with TTL `IDENTIFIER_EXPIRATION` (default 600s). This lets a
client poll `GET /api/v2/stats/identifier/:identifier` to see how its own submission moved through
the pipeline — this is the main tool for debugging "why didn't my data show up" issues.

### Metrics

Dedupe services and the PoW controller call `ActiveSupport::Notifications.instrument("metrics.*", payload)`.
`config/initializers/events.rb` subscribes to `/metrics\./` and hands events to
`ActiveSupportNotificationWorker` (Sidekiq), which calls `ActiveSupportNotificationService.process`.
That service batches points and writes them to InfluxDB2, gated by `METRICS_ENABLED=true`.

### Scheduled jobs

`config/initializers/sidekiq.rb` registers `sidekiq-cron` jobs directly in Ruby (not the DB) for
per-region `MarketOrderCleanupWorker`/`MarketHistoryCleanupWorker` and a periodic
`AlbionOnlineUpdateCheckWorker`. Cron job list is skipped when `SECRET_KEY_BASE_DUMMY` is set
(used during asset precompilation in the Docker build).

### Single image, multiple run modes

There's one Docker image; behavior is selected by `RUN_MODE` (or `entrypoint.sh $1`):
`web`, `sidekiq`, `nats`, `console`, `rspec`, `sleep`. `web`/`sidekiq`/`console`/`rspec` first wait
for MySQL and either run migrations (guarded by a Redis `SET NX` lock so only one container in a
multi-container deploy migrates) or, for `rspec`, create/reset the test databases via
`scripts/setup_databases.sh`.

### Public API

`app/controllers/api/v2/stats/` — `prices`, `history`, `gold`, `festivities`, `identifier`. All
JSON-only (`defaults: { format: 'json' }` in `config/routes.rb`). Rate limiting for `/api/v2/*` and
`/pow` is done via Rack::Attack (`config/initializers/rack_attack.rb`), backed by
`RACKATTACK_REDIS_URL` (falls back to Rails cache). `/pow` implements a proof-of-work challenge
(`app/controllers/pow_controller.rb`) gating something upstream of the ingest path.
