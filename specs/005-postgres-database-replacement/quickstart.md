# Quickstart: PostgreSQL Database Replacement

## 1) Generate State 010

```bash
bash pipeline/generate-state.sh 005-postgres-database-replacement
```

## 2) Start / Verify / Test / Stop

```bash
./scripts/start-state-005-postgres-database-replacement-generated.sh
./scripts/start-state-005-postgres-database-replacement-generated.sh --skip-build
./scripts/status-state-005-postgres-database-replacement-generated.sh
./scripts/test-state-005-postgres-database-replacement.sh
./scripts/stop-state-005-postgres-database-replacement-generated.sh
```
