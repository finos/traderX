# FINOS | TraderX Sample Trading App | Database

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

## Introduction

This is designed to play the role of a SQL database that runs standalone as part of an example environment. The other processes in this environment interact with this via SQL / JDBC drivers and therefore this component can be swapped out in other iterations of this environment and replaced with a robust and productionizable RDBMS.

This uses PostgreSQL as a standalone server, with basic authentication, and initializes with an empty SQL schema every time it is started.

## Default Port Numbers
| Protocol | Port Number |
| :--- | :--- |
| PostgreSQL | 5432 |
 
## Connecting to this database remotely
You can use the `$DATABASE_PORT` (5432) and the database URL in JDBC is `jdbc:postgresql://localhost:5432/traderx`

The default username and password are both *sa*

## Database Administration
PostgreSQL doesn't include a built-in web console. You can connect using:
- `psql` command line client
- pgAdmin (separate installation)
- Any PostgreSQL-compatible database client

Connection details:
- Host: localhost
- Port: 5432
- Database: traderx
- Username: sa
- Password: sa

## Output Directory
Data is stored in the local `./_data` directory from where the script is run. This is .gitignore'd 

## Building

This uses Docker to run PostgreSQL with initialization scripts.

```shell
$> docker build -t database .
```

## Running with Docker

This runs PostgreSQL in a Docker container with automatic schema initialization.

To launch:
```shell
$> docker run -p 5432:5432 -e POSTGRES_DB=traderx -e POSTGRES_USER=sa -e POSTGRES_PASSWORD=sa database
```

## Running with Docker Compose

The easiest way to run this is with the full TraderX stack:

```shell
$> docker compose up
```

The database will be available on port 5432. 


## Connecting to the Database

1. Use any PostgreSQL client (psql, pgAdmin, etc.)
2. Connection details:
   - Host: localhost
   - Port: 5432
   - Database: traderx
   - Username: sa
   - Password: sa
3. JDBC URL: `jdbc:postgresql://localhost:5432/traderx`
