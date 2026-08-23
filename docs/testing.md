# Testing

This app is developed and tested inside Docker — there is no supported bare-metal workflow (native
adapter is `trilogy`, three MySQL databases are required, plus Redis). The Docker Compose service
running the Rails app is named **`web`** (not `api`) in both `docker-compose.yml` and
`docker-compose-gha.yml`.

## One-time setup

```bash
cp .env.sample .env
```

`.env.sample` already defaults `RUN_MODE=sleep`, which is what you want for local dev/test — the
container stays up (`sleep infinity`) instead of immediately booting the Rails server, so you can
`exec` into it.

## Build

```bash
docker compose build
```

## Start the stack

```bash
docker compose up -d
```

This brings up `mysql`, `redis`, `influxdb`, and `web` (idling, per `RUN_MODE=sleep`).

## Run the full test suite

```bash
docker compose exec web ./scripts/setup_databases.sh   # first run / after schema changes: (re)creates west/east/europe test DBs
docker compose exec web bundle exec rake spec
```

`bundle exec rake spec` is the standard RSpec-Rails rake task (from the `rspec-rails` gem); it runs
everything under `spec/`.

## Run a single spec file or example

```bash
docker compose exec web bundle exec rspec spec/app/services/market_order_dedupe_service_spec.rb
docker compose exec web bundle exec rspec spec/app/services/market_order_dedupe_service_spec.rb:42
```

## Test config notes

- `spec/rails_helper.rb` sets `config.use_transactional_fixtures = false` — specs are **not**
  wrapped in a DB transaction by default. Factories (`spec/factories/`, FactoryBot) and any state
  a spec creates should be cleaned up deliberately if it isn't scoped to a dedicated test row/key.
- `config/database.yml`'s `test` block points every region (`west`/`east`/`europe`) at
  `<region url>_test`; `RAILS_ENV=test` plus `Multidb.use(:west|:east|:europe)` in specs exercises
  the same region-switching code path used in production.
- Region-scoped Redis (`REDIS['west']`/`REDIS['east']`/`REDIS['europe']`) is real Redis (the
  `redis` compose service), not mocked — dedupe-service specs that hit Redis keys should use
  distinct keys per example or clean up after themselves.
- Coverage: set `COVERAGE=on` to enable SimpleCov (`spec/rails_helper.rb`), e.g.
  `docker compose exec -e COVERAGE=on web bundle exec rake spec`.

## CI

`.github/workflows/rspec.yml` builds the image with Buildx and runs the suite via
`RUN_MODE=rspec docker compose -f docker-compose-gha.yml up --abort-on-container-exit`. `RUN_MODE=rspec`
makes `entrypoint.sh` create the test databases and run `bundle exec rake spec` directly (no
separate `exec` step, no `sleep` idling) — useful as a one-shot local sanity check too:

```bash
RUN_MODE=rspec docker compose -f docker-compose-gha.yml up --abort-on-container-exit
```

## Other useful commands inside the `web` container

```bash
docker compose exec web bundle exec rails c                 # console (also boots against real DBs)
docker compose exec web bundle exec rake aodp:db:migrate     # migrate all three regional DBs
docker compose exec web bin/rails routes                     # inspect routes
```
