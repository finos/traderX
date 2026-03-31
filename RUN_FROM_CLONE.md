# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`
- PostgreSQL: `localhost:18083`

Status / stop:

```bash
./scripts/status-state-009-postgres-database-replacement-generated.sh
./scripts/stop-state-009-postgres-database-replacement-generated.sh
```
