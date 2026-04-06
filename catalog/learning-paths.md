# Learning Paths Catalog

This file is generated from `catalog/state-catalog.json`.

## Baseline

- `001-baseline-uncontainerized-parity`: Simple App - Base Uncontainerized App

## Tracks

### Prelude

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`

### DevEx

- `009-kubernetes-runtime`
- `010-tilt-kubernetes-dev-loop`
- `011-platform-convergence-c3`
- `012-radius-kubernetes-platform`

### Architecture

- `004-postgres-database-replacement`
- `005-messaging-nats-replacement`

### Functional

- `007-pricing-awareness-market-data`
- `008-order-management-matcher`

### Non-Functional

- `006-observability-lgtm-compose`

### Optional

- `012-radius-kubernetes-platform`

### Convergence

- `003-containerized-compose-runtime`
- `006-observability-lgtm-compose`
- `008-order-management-matcher`
- `011-platform-convergence-c3`

## State Catalog

| State ID | Previous | Convergence | Is Convergence | Role | Spec |
| --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | none | `none` | `false` | `prelude` | `specs/001-baseline-uncontainerized-parity/spec.md` |
| `002-edge-proxy-uncontainerized` | 001-baseline-uncontainerized-parity | `none` | `false` | `prelude` | `specs/002-edge-proxy-uncontainerized/spec.md` |
| `003-containerized-compose-runtime` | 002-edge-proxy-uncontainerized | `C0` | `true` | `canonical` | `specs/003-containerized-compose-runtime/spec.md` |
| `004-postgres-database-replacement` | 003-containerized-compose-runtime | `none` | `false` | `canonical` | `specs/004-postgres-database-replacement/spec.md` |
| `005-messaging-nats-replacement` | 004-postgres-database-replacement | `none` | `false` | `canonical` | `specs/005-messaging-nats-replacement/spec.md` |
| `006-observability-lgtm-compose` | 005-messaging-nats-replacement | `C1` | `true` | `canonical` | `specs/006-observability-lgtm-compose/spec.md` |
| `007-pricing-awareness-market-data` | 006-observability-lgtm-compose | `none` | `false` | `canonical` | `specs/007-pricing-awareness-market-data/spec.md` |
| `008-order-management-matcher` | 007-pricing-awareness-market-data | `C2` | `true` | `canonical` | `specs/008-order-management-matcher/spec.md` |
| `009-kubernetes-runtime` | 008-order-management-matcher | `none` | `false` | `canonical` | `specs/009-kubernetes-runtime/spec.md` |
| `010-tilt-kubernetes-dev-loop` | 009-kubernetes-runtime | `none` | `false` | `canonical` | `specs/010-tilt-kubernetes-dev-loop/spec.md` |
| `011-platform-convergence-c3` | 010-tilt-kubernetes-dev-loop | `C3` | `true` | `canonical` | `specs/011-platform-convergence-c3/spec.md` |
| `012-radius-kubernetes-platform` | 009-kubernetes-runtime | `none` | `false` | `optional` | `specs/012-radius-kubernetes-platform/spec.md` |
