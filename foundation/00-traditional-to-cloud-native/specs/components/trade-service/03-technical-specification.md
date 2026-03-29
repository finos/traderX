# Trade-Service Technical Specification

## Component Identity

- Component ID: `trade-service`
- Type: service
- Baseline language/runtime: Java 21
- Framework/libraries: Spring Boot + Socket.IO Java client
- Build/run tool: Gradle (`./gradlew bootRun`)
- Default port: `18092`

## Runtime Configuration

- `TRADING_SERVICE_PORT` (default `18092`)
- `ACCOUNT_SERVICE_URL` (optional full URL override)
- `ACCOUNT_SERVICE_HOST` (default `localhost`, used when `ACCOUNT_SERVICE_URL` not set)
- `REFERENCE_DATA_SERVICE_URL` (optional full URL override)
- `REFERENCE_DATA_HOST` (default `localhost`, used when `REFERENCE_DATA_SERVICE_URL` not set)
- `PEOPLE_SERVICE_URL` (baseline compatibility setting; not in active request path for this component step)
- `PEOPLE_SERVICE_HOST` (baseline compatibility host setting)
- `TRADE_FEED_ADDRESS` (optional full URL override)
- `TRADE_FEED_HOST` (default `localhost`, used when `TRADE_FEED_ADDRESS` not set)
- `CORS_ALLOWED_ORIGINS` (default `*`)

## HTTP Contract

- `POST /trade/`:
  - request: `TradeOrder`
  - response (200): `TradeOrder` on successful validation and publish
  - response (404): resource-not-found for unknown ticker or account
- `GET /`: redirect to Swagger UI.

## Validation And Messaging Behavior

- Reference data validation call: `GET {reference.data.service.url}/stocks/{ticker}`
- Account validation call: `GET {account.service.url}/account/{id}`
- Publish target: trade-feed topic `/trades`
- Payload type: `TradeOrder`

## Build And Run Behavior

- Build: `./gradlew build`
- Run: `./gradlew bootRun`
- Readiness: TCP probe on `localhost:18092`

## Source Layout Target (Generated)

- Target path: `generated/code/components/trade-service-specfirst`
- Required generated artifacts:
  - Spring Boot source for controller, validation, and trade-feed publisher integration
  - Gradle build files and wrapper
  - Runtime properties and OpenAPI contract
