# Trade-Service (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18092` via `TRADING_SERVICE_PORT`
- Reference data endpoint: `REFERENCE_DATA_SERVICE_URL` or `REFERENCE_DATA_HOST`
- Account endpoint: `ACCOUNT_SERVICE_URL` or `ACCOUNT_SERVICE_HOST`
- People endpoint: `PEOPLE_SERVICE_URL` or `PEOPLE_SERVICE_HOST`
- Trade feed endpoint: `TRADE_FEED_ADDRESS` or `TRADE_FEED_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
