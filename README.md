# README

Don't use this. It's a work in progress that isn't ready yet.

# Creating database

Since we are using multidb, you need to create the databases in a non-standard ActiveReocrd way. 

Run 

- `./scripts/create_databases.sh` to create the databases.
- `./scripts/setup_databases.sh` to setup the databases.
- `./scripts/migrate_databases.sh` to apply migrations to the databases.

```ruby

# Redis Databases

0 - West Redis Cache
1 - East Redis Cache
2 - Europe Redis Cache
5 - ABUSEIPDB_REDIS_URL
6 - RACKATTACK_REDIS_URL
