# FINOS | TraderX Sample Trading App | Database

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

## Introduction

This is a PostgreSQL database that runs as part of the TraderX sample trading application environment. The other processes in this environment interact with this via SQL / JDBC drivers using the PostgreSQL protocol.

This uses PostgreSQL 16 as a containerized database server with basic authentication and initializes with a predefined SQL schema on first startup.

## Default Port Numbers
| Protocol | Port Number |
| :--- | :--- |
| PostgreSQL | 5432 |
 
## Connecting to this database remotely

**Connection Details:**
- **Host:** `localhost` (or `database` when connecting from other Docker containers)
- **Port:** `5432`
- **Database:** `traderx`
- **Username:** `sa`
- **Password:** `sa`
- **JDBC URL:** `jdbc:postgresql://localhost:5432/traderx` (or `jdbc:postgresql://database:5432/traderx` from containers)

## Database Schema

The database includes the following tables:
- **Accounts** - Trading accounts
- **AccountUsers** - User associations with accounts
- **Positions** - Current positions for each account
- **Trades** - Trade records

The schema is automatically initialized on first startup using the `initialSchema.sql` script.

## Data Persistence

Database data is persisted in a Docker volume named `postgres_data`. This ensures that data survives container restarts. To completely reset the database, you can remove this volume:

```shell
docker-compose down -v
```

## Building

The database service uses the official PostgreSQL 16 Docker image. No separate build step is required.

```shell
docker-compose build database
```

## Running

The database starts automatically when you run:

```shell
docker-compose up database
```

Or as part of the full TraderX stack:

```shell
docker-compose up
```

## Connecting with psql

You can connect to the database using the PostgreSQL command-line client:

```shell
docker-compose exec database psql -U sa -d traderx
```

Or from your local machine (if you have psql installed):

```shell
psql -h localhost -p 5432 -U sa -d traderx
```

## Connecting with GUI Tools

You can use any PostgreSQL-compatible GUI tool such as:
- pgAdmin
- DBeaver
- DataGrip
- Azure Data Studio (with PostgreSQL extension)

Use the connection details listed above.

## Environment Variables

The following environment variables can be configured in `docker-compose.yml`:

- `POSTGRES_DB` - Database name (default: `traderx`)
- `POSTGRES_USER` - Database user (default: `sa`)
- `POSTGRES_PASSWORD` - Database password (default: `sa`)

## Migration from H2

This database service has been migrated from H2 to PostgreSQL for better production readiness. The schema has been updated to be PostgreSQL-compatible while maintaining the same data structure and sample data.
