# Account-Service (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18088` via `ACCOUNT_SERVICE_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- People service: `PEOPLE_SERVICE_URL` or `PEOPLE_SERVICE_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
