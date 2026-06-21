# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-006-messaging-nats-replacement-generated.sh
./scripts/start-state-006-messaging-nats-replacement-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- NATS monitor: `http://localhost:8222/varz`

Status / stop:

```bash
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```

## Stable Entrypoints

Use root wrappers for this generated branch:

```bash
./start-env.sh   # start this state runtime
./status-env.sh  # runtime health/status
./stop-env.sh    # stop runtime
./test-env.sh    # state smoke/validation
```

Wrappers intentionally delegate to numbered state scripts to maximize reuse while keeping clone-first commands stable.
