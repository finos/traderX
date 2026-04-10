# Learning Paths Catalog

This file is generated from `catalog/state-catalog.json`.

## Baseline

- `001-baseline-uncontainerized-parity`: Simple App - Base Uncontainerized App

## Tracks

### Prelude

- `001-baseline-uncontainerized-parity`
- `002-edge-proxy-uncontainerized`
- `003-agentic-harness-foundation`

### DevEx

- `010-kubernetes-runtime`
- `011-tilt-kubernetes-dev-loop`
- `012-platform-convergence-c3`
- `013-radius-kubernetes-platform`

### Architecture

- `005-postgres-database-replacement`
- `006-messaging-nats-replacement`

### Functional

- `008-pricing-awareness-market-data`
- `009-order-management-matcher`

### Non-Functional

- `007-observability-lgtm-compose`

### Optional

- `013-radius-kubernetes-platform`

### Convergence

- `004-containerized-compose-runtime`
- `007-observability-lgtm-compose`
- `009-order-management-matcher`
- `012-platform-convergence-c3`

## State Catalog

| State ID | Previous | Convergence | Is Convergence | Role | Spec |
| --- | --- | --- | --- | --- | --- |
| `001-baseline-uncontainerized-parity` | none | `none` | `false` | `prelude` | `specs/001-baseline-uncontainerized-parity/spec.md` |
| `002-edge-proxy-uncontainerized` | 001-baseline-uncontainerized-parity | `none` | `false` | `prelude` | `specs/002-edge-proxy-uncontainerized/spec.md` |
| `003-agentic-harness-foundation` | 002-edge-proxy-uncontainerized | `none` | `false` | `prelude` | `specs/003-agentic-harness-foundation/spec.md` |
| `004-containerized-compose-runtime` | 003-agentic-harness-foundation | `C0` | `true` | `canonical` | `specs/004-containerized-compose-runtime/spec.md` |
| `005-postgres-database-replacement` | 004-containerized-compose-runtime | `none` | `false` | `canonical` | `specs/005-postgres-database-replacement/spec.md` |
| `006-messaging-nats-replacement` | 005-postgres-database-replacement | `none` | `false` | `canonical` | `specs/006-messaging-nats-replacement/spec.md` |
| `007-observability-lgtm-compose` | 006-messaging-nats-replacement | `C1` | `true` | `canonical` | `specs/007-observability-lgtm-compose/spec.md` |
| `008-pricing-awareness-market-data` | 007-observability-lgtm-compose | `none` | `false` | `canonical` | `specs/008-pricing-awareness-market-data/spec.md` |
| `009-order-management-matcher` | 008-pricing-awareness-market-data | `C2` | `true` | `canonical` | `specs/009-order-management-matcher/spec.md` |
| `010-kubernetes-runtime` | 009-order-management-matcher | `none` | `false` | `canonical` | `specs/010-kubernetes-runtime/spec.md` |
| `011-tilt-kubernetes-dev-loop` | 010-kubernetes-runtime | `none` | `false` | `canonical` | `specs/011-tilt-kubernetes-dev-loop/spec.md` |
| `012-platform-convergence-c3` | 011-tilt-kubernetes-dev-loop | `C3` | `true` | `canonical` | `specs/012-platform-convergence-c3/spec.md` |
| `013-radius-kubernetes-platform` | 012-platform-convergence-c3 | `none` | `false` | `optional` | `specs/013-radius-kubernetes-platform/spec.md` |
