# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-009-order-management-matcher-generated.sh
./scripts/start-state-009-order-management-matcher-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- Order matcher health: `http://localhost:18110/health`
- Grafana dashboards: `http://localhost:8080/grafana/`
- Grafana local admin: `http://localhost:3001`
- Prometheus: `http://localhost:9090`

Grafana access:
- Dashboards are anonymous Viewer surfaces through ingress.
- The start script prints the active local admin credential.
- Default convention: user from `TRADERX_GRAFANA_ADMIN_USER` or `traderx-admin`; password from `TRADERX_GRAFANA_ADMIN_PASSWORD` or `traderx-state-009`.

Smoke test:

```bash
./scripts/test-state-009-order-management-matcher.sh
./scripts/test-state-009-order-management-matcher.sh --skip-messaging
./scripts/test-messaging-009-order-management-matcher.sh
```

Status / stop:

```bash
./scripts/status-state-009-order-management-matcher-generated.sh
./scripts/stop-state-009-order-management-matcher-generated.sh
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
