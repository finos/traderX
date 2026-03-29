# Trade-Processor Technical Specification

## Component Identity

- Component ID: `trade-processor`
- Type: service
- Baseline language/runtime: Java 21
- Framework/libraries: Spring Boot + Spring Data JPA + Socket.IO Java client
- Build/run tool: Gradle (`./gradlew bootRun`)
- Default port: `18091`

## Runtime Configuration

- `TRADE_PROCESSOR_SERVICE_PORT` (default `18091`)
- `DATABASE_TCP_HOST` (default `localhost`)
- `DATABASE_TCP_PORT` (default `18082`)
- `DATABASE_NAME` (default `traderx`)
- `DATABASE_DBUSER` (default `sa`)
- `DATABASE_DBPASS` (default `sa`)
- `TRADE_FEED_ADDRESS` (optional full URL override)
- `TRADE_FEED_HOST` (default `localhost`, used when `TRADE_FEED_ADDRESS` is not set)
- `CORS_ALLOWED_ORIGINS` (default `*`)

## Data And Messaging Contracts

- Inbound topic: `/trades`
- Inbound payload type: `TradeOrder`
- Persisted entities:
  - `TRADES` with id/account/security/side/state/quantity/created/updated
  - `POSITIONS` with composite key account/security and quantity/updated
- Outbound topics:
  - `/accounts/{accountId}/trades`
  - `/accounts/{accountId}/positions`
- Outbound payloads:
  - `Trade` for trade updates
  - `Position` for position updates

## HTTP Contract

- `POST /tradeservice/order`: direct order processing compatibility endpoint.
- `GET /`: redirect to Swagger UI.

## Build And Run Behavior

- Build: `./gradlew build`
- Run: `./gradlew bootRun`
- Readiness: TCP probe on `localhost:18091`

## Source Layout Target (Generated)

- Target path: `generated/code/components/trade-processor-specfirst`
- Required generated artifacts:
  - Spring Boot application source (processing logic + messaging integration)
  - Gradle build files and wrapper
  - Runtime properties and OpenAPI contract
