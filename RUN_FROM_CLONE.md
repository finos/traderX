# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-010-pricing-awareness-market-data-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/prices`

Status / stop:

```bash
./scripts/status-state-010-pricing-awareness-market-data-generated.sh
./scripts/stop-state-010-pricing-awareness-market-data-generated.sh
```
