# Database Technical Specification

## Component Identity

- Component ID: `database`
- Type: service
- Baseline language/runtime: Java + H2 server tooling
- Build/run tool: Gradle + shell launcher
- Ports: `18082`, `18083`, `18084`

## Runtime Configuration

- `DATABASE_TCP_PORT` (default `18082`)
- `DATABASE_PG_PORT` (default `18083`)
- `DATABASE_WEB_PORT` (default `18084`)
- `DATABASE_DBUSER` (default `sa`)
- `DATABASE_DBPASS` (default `sa`)
- `DATABASE_DATA_DIR` (default `./_data`)
- `DATABASE_DBNAME` (default `traderx`)
- `DATABASE_WEB_HOSTNAMES`

## Initialization Contract

- Startup script must execute schema initialization against `initialSchema.sql`.
- Initialization must include sample baseline accounts/trades/positions data.
- Post-initialization, process must start persistent H2 server listeners on configured ports.

## Build And Run Behavior

- Build: `./gradlew build`
- Run: `./run.sh`
- Readiness: TCP probe on `localhost:18082`

## Source Layout Target (Generated)

- Target path: `generated/code/components/database-specfirst`
- Required artifacts:
  - startup script equivalent behavior to current `run.sh`
  - schema/init SQL file with baseline table/seed expectations
  - runtime configuration contract documentation
