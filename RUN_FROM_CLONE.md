# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-007-messaging-nats-replacement-generated.sh
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-007-messaging-nats-replacement-generated.sh
./scripts/stop-state-007-messaging-nats-replacement-generated.sh
```
