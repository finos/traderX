# Feature Specification: Order Management and Matcher

**Feature Branch**: `009-order-management-matcher`  
**Created**: 2026-04-05  
**Status**: Implemented  
**Input**: Transition delta from `008-pricing-awareness-market-data`

## User Stories

- As a trader, I want to submit limit orders from a dedicated order ticket so market trades and limit orders are distinct workflows.
- As a trader, I want an orders blotter view for my selected account so I can monitor and cancel outstanding orders without leaving the main trade page.
- As an operations user, I want an admin view to inspect, filter, cancel, and force-fill orders across all accounts.
- As a platform engineer, I want order-specific observability so queue depth and open/unfilled orders are visible at all times.
- As a maintainer, I want this transition to remain spec-first, with order APIs/events/metrics documented before code generation.

## Functional Requirements

- FR-01301: State introduces order lifecycle management with statuses: `NEW`, `PARTIALLY_FILLED`, `FILLED`, `CANCELED`, `REJECTED`.
- FR-01302: State adds an order matcher component (Spring Boot) that evaluates open orders and emits fill outcomes.
- FR-01303: State adds a dedicated order ticket in the trader UI for creating limit orders (`security`, `side`, `quantity`, `limitPrice`, `accountId`).
- FR-01304: State adds an account-scoped orders blotter in the trader UI (tabbed with the trade blotter context) for viewing and canceling open orders.
- FR-01305: State adds an order admin view in the web UI (`Admin` tab) for cross-account inspection plus `cancel` and `force-fill` actions.
- FR-01306: Order submission, cancellation, and force-fill flows are exposed through order APIs and are propagated in realtime via messaging subjects.
- FR-01311: Order matcher publishes order lifecycle updates to `/accounts/{accountId}/orders` (account scope) and `/orders` (all accounts) for every persisted transition (`NEW`, `PARTIALLY_FILLED`, `FILLED`, `CANCELED`, `REJECTED`).
- FR-01312: Published order events use the same payload contract as order REST responses so UI consumers can apply updates without an immediate follow-up HTTP fetch.
- FR-01313: Realtime TraderX views (`trade` blotter, `position` blotter, account order blotter, and admin order blotter) SHALL subscribe to messaging subjects and apply push updates as their source of incremental change.
- FR-01314: Realtime views SHALL bootstrap initial state from REST and then continue via pub/sub stream updates, without requiring periodic background polling loops.
- FR-01315: API explorer pub/sub inspector contract introduced in state `008` SHALL be preserved, and generated inspector topic buttons SHALL include order subjects (`/accounts/{accountId}/orders`, `/orders`) in this state.
- FR-01308: Order data is persisted in the shared database so active orders survive order-matcher service restarts.
- FR-01309: On every matcher tick, in-the-money orders are auto-filled with this policy: remaining `< 1000` fills fully, otherwise fills half (rounded up).
- FR-01310: Any order fill (auto-fill or force-fill) must submit a trade through trade-service so trade history and account positions are updated via the existing trade pipeline.
- FR-01307: Existing pricing + trade + position flows from state `008` remain compatible unless explicitly changed in this pack.

## Non-Functional Requirements

- NFR-01301: Observability stack from `007` remains intact and now covers order-management components and endpoints.
- NFR-01302: Order matcher service exposes Prometheus metrics for order book depth and lifecycle transitions.
- NFR-01303: A gauge metric reports open unfilled orders in near real time and is queryable in Grafana/Prometheus.
- NFR-01304: Grafana includes order-management dashboards for open orders, fill/cancel rates, matcher latency, and error signals.
- NFR-01305: Runtime and topology constraints are captured in `system/runtime-topology.md`.
- NFR-01306: Architecture updates are encoded in `system/architecture.model.json`.
- NFR-01307: Order matcher runtime uses Java 21 + Spring Boot for consistency with existing TraderX JVM services and shared operational patterns.
- NFR-01308: Every service in this state that exposes Prometheus-compatible metrics MUST be scraped by Prometheus and represented in provisioned Grafana dashboards.
- NFR-01309: As convergence level `C2`, generated state branches MUST include `.github/workflows/build-and-publish.yml` for container image publication.
- NFR-01310: `C2` image publication namespace MUST use `ghcr.io/finos/traderx-c2/<component>` with immutable commit-SHA tags plus `latest`.
- NFR-01311: Generated artifacts MUST include a GHCR run bundle for running this state from published images.
- NFR-01312: Generator output MUST deterministically include `database/initialSchema.sql` with an `OrderBook` table definition whenever `order-matcher` is present in generated state artifacts.
- NFR-01313: Generated-state publish gates MUST fail if `order-matcher` is present and the generated database schema contract for `OrderBook` is missing.
- NFR-01314: Order-facing UI views (`trade` order blotter, admin order view) MUST use messaging-bus push subscriptions for live updates and MUST NOT run periodic background polling loops against `GET /orders`.
- NFR-01315: Trade and position blotters MUST retain push-based realtime updates (`/accounts/{accountId}/trades`, `/accounts/{accountId}/positions`) after initial REST bootstrap and MUST NOT introduce periodic polling loops as a substitute for stream updates.
- NFR-01316: Generated API explorer catalog for this state SHALL include cumulative `messagingSubjects` metadata for inspector topic generation, including wildcard semantics (`pricing.*`) and parameterized subject prefill patterns.

## Success Criteria

- SC-01301: Generation hook exists and is runnable (`pipeline/generate-state-009-order-management-matcher.sh`).
- SC-01302: State smoke test path is defined (`scripts/test-state-009-order-management-matcher.sh`).
- SC-01303: Smoke checks validate user journeys for order create, account-filtered order listing, user cancel, and admin force-fill.
- SC-01304: Smoke checks validate matcher auto-fill policy for in-the-money orders and terminal completion.
- SC-01305: Smoke checks validate that a filled order appears as a trade and updates the corresponding account position.
- SC-01306: Smoke checks validate observability for order components, including open/unfilled order gauges.
- SC-01307: Grafana dashboards are provisioned for order book health and matcher throughput/latency.
- SC-01308: Generated snapshot branch and tag strategy are defined in state catalog.
- SC-01309: Generated branch artifacts include `C2` build/publish workflow and GHCR run-bundle assets.
- SC-01310: `pipeline/validate-generated-state-contracts.sh` fails on generated snapshots that include `order-matcher` without `OrderBook` schema and passes when the contract is present.
- SC-01311: Smoke checks validate that open-order views update in real time on create/auto-fill/cancel/force-fill via `/accounts/{accountId}/orders` and `/orders`, without periodic `GET /orders` polling traffic.
- SC-01312: Smoke checks validate `/api/docs/pubsub-inspector.html` availability and topic metadata coverage against `system/messaging-subject-map.md`.
