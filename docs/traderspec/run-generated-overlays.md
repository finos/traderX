---
title: Run Generated Baseline
---

# Run Generated Baseline

This is the canonical runbook for the base uncontainerized generated runtime.

## Regenerate All Base Components

```bash
bash pipeline/generate-state.sh 001-baseline-uncontainerized-parity
```

## Start Full Overlay Stack

```bash
CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

Optional if dependencies are already cached:

```bash
TRADERSPEC_SKIP_NETWORK_CHECK=1 CORS_ALLOWED_ORIGINS=http://localhost:18093 ./scripts/start-base-uncontainerized-generated.sh
```

## Dry Run

```bash
./scripts/start-base-uncontainerized-generated.sh --dry-run
```

## Smoke Test Suite

```bash
./scripts/test-reference-data-overlay.sh
./scripts/test-database-overlay.sh
./scripts/test-people-service-overlay.sh
./scripts/test-account-service-overlay.sh
./scripts/test-position-service-overlay.sh
./scripts/test-trade-feed-overlay.sh
./scripts/test-trade-processor-overlay.sh
./scripts/test-trade-service-overlay.sh
./scripts/test-web-angular-overlay.sh
```

## Stop

```bash
./scripts/stop-base-uncontainerized-generated.sh
```

## State 002 (Edge Proxy) Runtime

Generate and start:

```bash
bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized
./scripts/start-state-002-edge-proxy-generated.sh
```

Smoke test:

```bash
./scripts/test-state-002-edge-proxy.sh
```

Stop:

```bash
./scripts/stop-state-002-edge-proxy-generated.sh
```
