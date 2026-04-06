---
title: "State 006: Observability with LGTM on Compose"
---

# State 006 Learning Guide

## Position In Learning Graph

- Previous state(s): [005-messaging-nats-replacement](/docs/learning/state-005-messaging-nats-replacement)
- Dotted-line parent(s): none
- Next state(s): [007-pricing-awareness-market-data](/docs/learning/state-007-pricing-awareness-market-data)

## Convergence Metadata

- Convergence state: `yes`
- Convergence level: `C1`
- Lineage role: `canonical`
- Nearest previous convergence: [003-containerized-compose-runtime](/docs/learning/state-003-containerized-compose-runtime)
- Nearest next convergence: [008-order-management-matcher](/docs/learning/state-008-order-management-matcher)

## Rendered Code

- Generated branch: [code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/tree/code/generated-state-006-observability-lgtm-compose)
- Authoring branch (spec source): [feature/agentic-renovation](https://github.com/finos/traderX/tree/feature/agentic-renovation)

## Code Comparison With Previous State

- Compare against `005-messaging-nats-replacement`: [code/generated-state-005-messaging-nats-replacement...code/generated-state-006-observability-lgtm-compose](https://github.com/finos/traderX/compare/code%2Fgenerated-state-005-messaging-nats-replacement...code%2Fgenerated-state-006-observability-lgtm-compose)

## Plain-English Code Delta

- **Flow Impact:** No functional flow changes from state `005`.
- **Flow Impact:** Existing flow IDs remain valid; this state only adds runtime observability capabilities.

## Run This State

```bash
./scripts/start-state-006-observability-lgtm-compose-generated.sh
```

## Canonical Spec Links

- State spec pack: [/specs/observability-lgtm-compose](/specs/observability-lgtm-compose)
- Architecture: [/specs/observability-lgtm-compose/system/architecture](/specs/observability-lgtm-compose/system/architecture)
- Flows / topology: [/specs/observability-lgtm-compose/system/runtime-topology](/specs/observability-lgtm-compose/system/runtime-topology)
- Research: [link](/specs/observability-lgtm-compose/research)
- Data model: [link](/specs/observability-lgtm-compose/data-model)
- Quickstart: [link](/specs/observability-lgtm-compose/quickstart)
- State ADR: [link](/docs/adr/007-state-006-adopt-lgtm-observability-stack)
