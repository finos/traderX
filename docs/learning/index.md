---
title: Learning Guide
---

# Learning Guide

Learn by building and explaining a working system, one architectural or domain decision at a time.

Start with [How to learn with TraderX states](/docs/learning/how-to-learn), then choose a chapter below or explore the [visual state diagram](/docs/learning-paths). Each chapter carries forward prior knowledge, introduces a concrete change, and asks you to explain the evidence you observe.

Canonical requirements, contracts, and architecture remain in `specs/**`.  
These guides explain how to read each generated code snapshot, compare it to previous states, and understand the code delta in plain English.

For the visual progression map, see [Visual Learning Paths](/docs/learning-paths).

## State Guide Catalog

| Chapter | What you will learn | Start from |
| --- | --- | --- |
| [001: Follow a trade beyond the screen](/docs/learning/state-001-baseline-uncontainerized-parity) | Trace the browser, trade service, event transport, processor, database and position view as one business workflow. | Foundation: start here |
| [002: Give the browser one entry point](/docs/learning/state-002-edge-proxy-uncontainerized) | Route UI, REST and streaming traffic through one NGINX edge while retaining the baseline business flow. | [001-baseline-uncontainerized-parity](/docs/learning/state-001-baseline-uncontainerized-parity) |
| [003: Make an agent work within an explicit contract](/docs/learning/state-003-agentic-harness-foundation) | Add generated instructions, architecture context and contributor guidance for repeatable agent-assisted work. | [002-edge-proxy-uncontainerized](/docs/learning/state-002-edge-proxy-uncontainerized) |
| [004: Containerize the application, then run it with Compose](/docs/learning/state-004-containerized-compose-runtime) | Containerize the application services and web frontend, then use Docker Compose to run the containers together behind NGINX and check readiness. | [003-agentic-harness-foundation](/docs/learning/state-003-agentic-harness-foundation) |
| [005: Replace persistence without changing the business contract](/docs/learning/state-005-postgres-database-replacement) | Move persistence to PostgreSQL while retaining account, trade and position behavior. | [004-containerized-compose-runtime](/docs/learning/state-004-containerized-compose-runtime) |
| [006: Separate messaging semantics from transport](/docs/learning/state-006-messaging-nats-replacement) | Replace internal messaging with NATS while preserving the trade-to-position workflow. | [005-postgres-database-replacement](/docs/learning/state-005-postgres-database-replacement) |
| [007: Explain behavior with telemetry](/docs/learning/state-007-observability-lgtm-compose) | Add LGTM telemetry to connect a user action with logs, metrics and traces. | [006-messaging-nats-replacement](/docs/learning/state-006-messaging-nats-replacement) |
| [008: Distinguish a market observation from a trade](/docs/learning/state-008-pricing-awareness-market-data) | Stream simulated market data and use price awareness while retaining the booking workflow. | [007-observability-lgtm-compose](/docs/learning/state-007-observability-lgtm-compose) |
| [009: Model an order before it becomes a trade](/docs/learning/state-009-order-management-matcher) | Introduce limit orders, matching and fills while keeping orders distinct from executed trades. | [008-pricing-awareness-market-data](/docs/learning/state-008-pricing-awareness-market-data) |
| [010: Move the runtime without changing the trading lesson](/docs/learning/state-010-kubernetes-runtime) | Run C2 on Kubernetes and explain ingress, service routing and pod readiness. | [009-order-management-matcher](/docs/learning/state-009-order-management-matcher) |
| [011: Shorten the edit-and-observe loop](/docs/learning/state-011-tilt-kubernetes-dev-loop) | Use Tilt to orchestrate the local Kubernetes development loop. | [010-kubernetes-runtime](/docs/learning/state-010-kubernetes-runtime) |
| [012: Establish a reusable platform checkpoint](/docs/learning/state-012-platform-convergence-c3) | Treat C3 as a combined platform and functional checkpoint for subsequent branches. | [011-tilt-kubernetes-dev-loop](/docs/learning/state-011-tilt-kubernetes-dev-loop) |
| [013: Explore a platform abstraction as an alternative](/docs/learning/state-013-radius-kubernetes-platform) | Use Radius to describe the application and its resource relationships on Kubernetes. | [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3) |
| [014: Pass intent between applications without executing a trade](/docs/learning/state-014-fdc3-intent-interoperability) | Add FDC3 context and intent handling through Sail so another application can open a prefilled ticket. | [012-platform-convergence-c3](/docs/learning/state-012-platform-convergence-c3) |

## How To Use This Section

1. Open a state guide from this catalog.
2. Read its purpose and incoming transition, then follow the guided experiment.
3. Record observations and answer the assessment questions.
4. Use the system references and code comparison to explain what changed, then choose an onward learning state.

## Recommended Starting Points For New State Design

- `004-containerized-compose-runtime` (C0): Containerized Compose Runtime (NGINX Ingress)
- `007-observability-lgtm-compose` (C1): Observability with LGTM on Compose
- `009-order-management-matcher` (C2): Order Management and Matcher
- `012-platform-convergence-c3` (C3): Platform Convergence C3
