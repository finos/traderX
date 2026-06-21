# Quickstart: Platform Convergence C3

## 1) Generate State 012

```bash
bash pipeline/generate-state.sh 012-platform-convergence-c3
```

## 2) Start / Verify / Test / Stop (kind)

```bash
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/start-state-012-platform-convergence-c3-generated.sh --provider kind --skip-build
./scripts/status-state-012-platform-convergence-c3-generated.sh --provider kind
./scripts/test-state-012-platform-convergence-c3.sh http://localhost:8080 traderx kind traderx-state-012
./scripts/stop-state-012-platform-convergence-c3-generated.sh --provider kind
```

## Apple Silicon / Published Images

Published C3 images are built for the generated branch target and may run under amd64 emulation on Apple Silicon. Expect Spring services to take longer to accept ingress traffic than local native builds.

Use published images when validating GHCR branch parity:

```bash
TRADERX_SKIP_GENERATE=1 \
TRADERX_USE_PUBLISHED_IMAGES=1 \
TRADERX_PUBLISHED_NAMESPACE=traderx-c3 \
TRADERX_PUBLISHED_TAG=latest \
./scripts/start-state-012-platform-convergence-c3-generated.sh \
  --provider kind \
  --skip-build \
  --cluster-name traderx-state-012
```

Use local native image builds when validating local changes or startup timing on Apple Silicon. Readiness waits default to a longer timeout on `arm64` when `TRADERX_USE_PUBLISHED_IMAGES=1`; override with `TRADERX_SMOKE_READY_TIMEOUT=<seconds>` when a local host needs more or less time.
