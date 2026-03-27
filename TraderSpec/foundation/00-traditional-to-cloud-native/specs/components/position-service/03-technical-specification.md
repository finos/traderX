# Position-Service Technical Specification

## Component Identity

- Component ID: `position-service`
- Type: service
- Baseline language/runtime: Java + Spring Boot
- Build/run tool: Gradle (`./gradlew bootRun`)
- Default port: `18090`

## Runtime Configuration

- `POSITION_SERVICE_PORT` (default `18090`)
- `DATABASE_TCP_HOST` (default `localhost`)
- `DATABASE_TCP_PORT` (default `18082`)
- `DATABASE_NAME` (default `traderx`)
- `DATABASE_DBUSER` (default `sa`)
- `DATABASE_DBPASS` (default `sa`)
- `CORS_ALLOWED_ORIGINS` (default `*`)

## API Contract

- `GET /trades/{accountId}`
- `GET /trades/`
- `GET /positions/{accountId}`
- `GET /positions/`
- `GET /health/ready`
- `GET /health/alive`

## Integration Contract

- Reads from baseline DB tables:
  - `Trades` for trade blotter data
  - `Positions` for aggregated position view
- No mutation endpoints in baseline for this service.

## Build And Run Behavior

- Build: `./gradlew build`
- Run: `./gradlew bootRun`
- Readiness: TCP probe on `localhost:18090`

## Source Layout Target (Generated)

- Target path: `TraderSpec/codebase/generated-components/position-service-specfirst`
- Required generated artifacts:
  - Spring Boot service with trades/positions/health controllers
  - repository layer compatible with baseline schema
  - CORS configuration for pre-ingress local runtime
