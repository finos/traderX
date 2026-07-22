# Database (Spec-First Generated)

This component is synthesized from the TraderSpec Spec Kit manifest for the baseline pre-containerized runtime.

## Run

```bash
./gradlew build
./run.sh
```

## Runtime Contract

- Default TCP port: `18082` via `DATABASE_TCP_PORT`
- Default PG port: `18083` via `DATABASE_PG_PORT`
- Default web console port: `18084` via `DATABASE_WEB_PORT`
- Web hostname allowlist env: `DATABASE_WEB_HOSTNAMES`
