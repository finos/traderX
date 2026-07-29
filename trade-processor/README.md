# Trade-Processor (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18091` via `TRADE_PROCESSOR_SERVICE_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- Trade feed: `TRADE_FEED_ADDRESS` or `TRADE_FEED_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
