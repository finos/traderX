# Run From Clone

Prerequisites:
- Docker
- kubectl
- jq
- Kind (default) or Minikube
- Docker Compose plugin (required for optional Sail sidecar mode)

Start TraderX runtime (state 014 wrapper):

```bash
./start-env.sh --provider kind
```

Start TraderX + Sail sidecar demo mode:

```bash
./start-env.sh --provider kind --with-sail
```

Endpoints:
- UI / edge: `http://localhost:8080`
- API explorer (edge): `http://localhost:8080/api/docs`
- Sail UI (when `--with-sail`): `http://localhost:8090`

Status / stop:

```bash
./status-env.sh --provider kind
./stop-env.sh --provider kind
```

Functional smoke test:

```bash
./test-env.sh
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
