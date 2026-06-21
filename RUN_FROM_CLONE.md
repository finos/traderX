# Run From Clone

Prerequisites:
- Docker Desktop (or Docker Engine + Compose plugin)

Start:

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
./scripts/start-state-008-pricing-awareness-market-data-generated.sh --skip-build
```

Endpoints:
- UI / ingress: `http://localhost:8080`
- API explorer (ingress): `http://localhost:8080/api/docs`
- Ingress health: `http://localhost:8080/health`
- Grafana dashboards: `http://localhost:8080/grafana/`
- Grafana local admin: `http://localhost:3001`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/prices`

Grafana access:
- Dashboards are anonymous Viewer surfaces through ingress.
- The start script prints the active local admin credential.
- Default convention: user from `TRADERX_GRAFANA_ADMIN_USER` or `traderx-admin`; password from `TRADERX_GRAFANA_ADMIN_PASSWORD` or `traderx-state-008`.

Smoke test:

```bash
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
```

Status / stop:

```bash
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
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
