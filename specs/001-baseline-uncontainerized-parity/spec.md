# Feature Specification: Simple App - Base Uncontainerized App

**Feature Branch**: `001-baseline-uncontainerized-parity`  
**Created**: 2026-03-28  
**Status**: Draft  
**Input**: User description: "Define TraderX baseline behavior and constraints so generated code can reproduce current runtime behavior without relying on source hydration."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deterministic Developer Startup (Priority: P1)

As a developer, I need to start the full baseline stack in a known order with known ports so the system is runnable and debuggable on a local machine.

**Why this priority**: Without deterministic startup there is no usable baseline for any functional validation.

**Independent Test**: Run start/status scripts and verify all services are ready on expected ports.

**Acceptance Scenarios**:

1. **Given** runtime dependencies are installed, **When** baseline start script runs, **Then** all required services reach ready state on expected ports.
2. **Given** the stack is running, **When** status checks run, **Then** each service reports healthy/readiness state.

---

### User Story 2 - Account + Blotter Bootstrap (Priority: P1)

As a trader, I need account list and initial trades/positions loading so I can begin workflow in the Angular UI.

**Why this priority**: This is the minimum viable user-visible behavior in the baseline UI.

**Independent Test**: Load UI, select account, verify account list and blotter bootstrap requests succeed.

**Acceptance Scenarios**:

1. **Given** the UI loads, **When** accounts are requested, **Then** account-service returns account list and UI renders selectable accounts.
2. **Given** an account is selected, **When** blotter bootstrap runs, **Then** position-service returns trades and positions and UI subscribes to account topics.

---

### User Story 3 - Trade Submission and Processing (Priority: P1)

As a trader, I need valid trade submissions to be accepted and then processed into trade/position updates.

**Why this priority**: Core trading flow is the primary project behavior.

**Independent Test**: Submit valid trade, verify publish/process/persist/update chain and UI/endpoint visibility.

**Acceptance Scenarios**:

1. **Given** a valid account+ticker trade ticket, **When** it is submitted to trade-service, **Then** it is validated and published to trade-feed.
2. **Given** a new trade event, **When** trade-processor consumes it, **Then** trade records/positions are persisted and account topic updates are published.
3. **Given** a websocket client subscribed to account trade and position topics, **When** a valid trade is submitted through trade-service, **Then** the client receives incremental trade and position updates without page refresh.
4. **Given** an existing position row for a security is already shown in the UI, **When** a websocket position update arrives for that same security, **Then** the existing row is updated in place instead of adding a duplicate row.

---

### User Story 4 - Account Administration (Priority: P2)

As an operations user, I need to create/update accounts and assign users validated by people-service.

**Why this priority**: Administrative flows are required for multi-user/account maintenance.

**Independent Test**: Execute account CRUD and account-user mapping calls including known/unknown user validation paths.

**Acceptance Scenarios**:

1. **Given** account create/update payload, **When** submitted, **Then** account data persists and is retrievable.
2. **Given** account-user mapping request, **When** username is unknown in people-service, **Then** mapping is rejected.

---

### User Story 5 - Cross-Account Monitoring UX (Priority: P2)

As a trader, I need an **All Accounts** view that aggregates blotters while preventing ambiguous order entry.

**Why this priority**: Baseline demos and learning flows frequently require cross-account visibility without sacrificing safe ticket semantics.

**Independent Test**: Use UI contract checks to verify all-accounts selection, aggregated blotter wiring, and ticket-disable behavior.

**Acceptance Scenarios**:

1. **Given** `All Accounts` is selected, **When** blotter bootstrap runs, **Then** trades and positions are loaded in cross-account mode.
2. **Given** `All Accounts` is selected, **When** the user opens trade ticket, **Then** ticket creation is disabled and explanatory guidance is shown.

---

### User Story 6 - Search + Identity UX (Priority: P2)

As a trader/operations user, I need reliable security lookup and human-readable account-user names.

**Why this priority**: Faster security entry and full-name user displays improve baseline usability without changing core trading semantics.

**Independent Test**: Verify typeahead and account-user enrichment contracts in generated Angular source and smoke checks.

**Acceptance Scenarios**:

1. **Given** trade ticket security input, **When** user types, **Then** typeahead uses combined ticker/company matching and browser autocomplete is disabled.
2. **Given** account users list is rendered, **When** people-service lookup succeeds, **Then** full names are shown (with username fallback on lookup error).

---

### User Story 7 - State-Aware Header + About Experience (Priority: P2)

As a learner, I need the header and About page to clearly identify which TraderX state I am running and where it came from.

**Why this priority**: State identity and lineage are core learning outcomes in this repository and reduce confusion when switching generated snapshots.

**Independent Test**: Run UI smoke contract checks that verify header title content, About navigation, and About metadata bindings.

**Acceptance Scenarios**:

1. **Given** the UI header is rendered, **When** logo/title area is visible, **Then** title text is `TraderX Sample Trading App (001-baseline-uncontainerized-parity)`.
2. **Given** the top navigation is rendered, **When** user selects `About`, **Then** an About page is shown with state id, generated timestamp, source branch, and previous-state lineage details.
3. **Given** the About page is shown, **When** metadata is rendered, **Then** each previous state entry includes its publish branch and a short feature summary sentence derived from state catalog metadata.
4. **Given** the About page is shown, **When** user wants contract exploration, **Then** a link to the API explorer is available.

---

### User Story 8 - Runtime State Detection Before Startup (Priority: P2)

As a developer, I need startup commands to report what state is currently generated so I can decide whether to regenerate before running.

**Why this priority**: Generated outputs share mutable directories; silent state mismatches are a common source of debugging confusion.

**Independent Test**: Run state start scripts against matched and mismatched generated outputs and verify detection and guidance messages.

**Acceptance Scenarios**:

1. **Given** runtime start script is invoked, **When** generated state metadata does not match expected state, **Then** script reports expected/current state ids and guidance for regenerate vs clean rebuild.
2. **Given** a forward state mismatch is detected, **When** developer opts into auto-regeneration, **Then** script can regenerate expected state before continuing.
3. **Given** state metadata matches expected state, **When** startup begins, **Then** script reports match and continues with normal startup flow.

### Edge Cases

- Unknown ticker must return `404` and no new trade publish.
- Unknown account must return `404` on trade/account lookups.
- Unknown person must return `404` and block account-user mapping persistence.
- Missing CORS headers in pre-ingress mode must be treated as a baseline non-functional failure.
- Service not ready in startup sequence must stop later dependents and emit clear diagnostics.
- Realtime position updates must not create duplicate UI rows for the same `(account, security)` key.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST start baseline services in deterministic order: database, reference-data, trade-feed, people-service, account-service, position-service, trade-processor, trade-service, web-front-end-angular.
- **FR-002**: System MUST expose and respect baseline default ports for all baseline processes.
- **FR-003**: UI MUST load account list through account-service.
- **FR-004**: UI MUST load trades and positions for selected account through position-service.
- **FR-005**: UI MUST subscribe to account-scoped trade and position topics through trade-feed.
- **FR-006**: reference-data MUST provide ticker list and ticker-by-symbol lookup endpoints.
- **FR-007**: trade-service MUST validate ticker and account before publishing new trade events.
- **FR-008**: trade-processor MUST persist new trades, update trade state, and upsert positions.
- **FR-009**: account-service MUST provide account create/update and account-user mapping operations.
- **FR-010**: people-service MUST provide person search/lookup validation used by account-service.
- **FR-011**: All generated baseline services MUST preserve current approved API contracts under this feature's `contracts/` folder.
- **FR-012**: Startup/status/overlay smoke scripts MUST be runnable from repository automation.
- **FR-013**: Generated implementation MUST run without copying code from deleted legacy root component directories.
- **FR-014**: Submitting a valid trade through trade-service MUST emit realtime account-scoped trade and position topic updates consumable by websocket clients.
- **FR-015**: The UI position blotter MUST upsert realtime position updates by security key, updating existing rows in place rather than appending duplicates.
- **FR-016**: The UI MUST provide an `All Accounts` option that enables cross-account trades view and merged-by-security positions view.
- **FR-017**: The UI MUST disable trade-ticket creation while `All Accounts` is selected and provide explanatory feedback.
- **FR-018**: Trade ticket security lookup MUST use combined ticker/company typeahead matching with browser autocomplete disabled.
- **FR-019**: Account-user administration view MUST display people-service `fullName` values (with username fallback).
- **FR-020**: The top-bar application title next to the upper-left logo MUST render as `TraderX Sample Trading App (<state-id>)`, where `<state-id>` is the active generated state id.
- **FR-021**: The top navigation MUST include an `About` tab/link that routes to an About page for the active state.
- **FR-022**: The About page MUST render: active state id, generation timestamp, source generated-state branch, and prior-state lineage entries including previous-state branch links and short feature summary sentences.
- **FR-023**: The About page MUST include a direct link to the state API explorer.
- **FR-024**: About-page lineage metadata MUST be dynamically derived from repository state metadata artifacts (at minimum `catalog/state-catalog.json` plus generated state metadata).

### Non-Functional Requirements

- **NFR-001 (Technical Stack Fidelity)**: Generated components MUST keep the baseline language/framework/toolchain profile defined in this feature pack (`Java/Spring`, `TypeScript/Nest`, `Node/Socket.IO`, `.NET`, `Angular`, `Gradle`, `npm`, `dotnet`).
- **NFR-002 (Runtime Interface Fidelity)**: Generated components MUST keep baseline ports, required environment variables, and dependency wiring compatible with baseline startup scripts.
- **NFR-003 (Contract Fidelity)**: Generated REST contracts MUST match canonical OpenAPI artifacts under `contracts/**` unless a spec-approved contract change is introduced.
- **NFR-004 (Cross-Origin Baseline Support)**: For pre-ingress base state, components serving browser traffic MUST emit CORS headers sufficient for cross-port UI calls.
- **NFR-005 (Code Closeness Gate)**: Generation output MUST pass semantic comparison against the approved baseline with no differences in `source-code`, `runtime-config`, or `api-contract` categories.
- **NFR-006 (Deterministic Generation)**: Re-running generation from unchanged specs MUST produce stable output with no unexpected drift.
- **NFR-007 (Traceable Derivation)**: Every major generated component behavior MUST map to plain-English requirement statements and to technical constraints (ports/env/contracts/dependencies).
- **NFR-008 (Responsive Blotters)**: Trade and position blotters MUST preserve readability across viewport sizes via side-by-side wrapping layout with minimum pane width constraints.
- **NFR-009 (Runtime State Detection)**: State runtime/start scripts MUST detect the currently generated state id before startup and emit explicit guidance for mismatch handling (including clean-rebuild guidance when moving backwards in lineage).
- **NFR-010 (Optional Auto-Regeneration)**: Runtime/start scripts MUST support an explicit opt-in mode to auto-regenerate the expected state before startup when mismatch is detected.
- **NFR-011 (Lifecycle Script Contract)**: Generated states MUST expose separated lifecycle commands for build, start, stop, and readiness checks. For uncontainerized states this is `start --build-only`, `start`, `stop`, and `smoke`; for containerized/Kubernetes states `--skip-build` is the accepted build/start separation mode.

### Key Entities *(include if feature involves data)*

- **Account**: Trading account aggregate identified by `accountId` and display metadata.
- **AccountUser**: Mapping of usernames to accounts (many-to-many).
- **Person**: Directory user record used for validation and display.
- **TradeOrder**: Client-submitted trade request payload.
- **Trade**: Persisted trade lifecycle record.
- **Position**: Account+ticker aggregate quantity.
- **SecurityReference**: Ticker and company metadata from reference-data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Full baseline startup reaches ready state for all nine baseline services in a single script run.
- **SC-002**: Overlay smoke tests pass for all generated baseline components.
- **SC-003**: Angular baseline UI loads account list and blotter data for a valid account without browser CORS errors.
- **SC-004**: Valid trade submission is acknowledged and appears in position-service views after processing.
- **SC-005**: Unknown ticker, unknown account, and unknown username negative-path checks return expected HTTP status codes.
- **SC-006**: Contract artifacts in `specs/001-baseline-uncontainerized-parity/contracts/**` stay synchronized with generated component OpenAPI files.
- **SC-007**: Semantic compare harness reports zero differences in `source-code`, `runtime-config`, and `api-contract` categories for baseline components.
- **SC-008**: Baseline component technical profile (`fidelity-profile.md`) and generated manifests remain aligned.
- **SC-009**: An automated websocket functional test can subscribe to account trade/position topics, submit a trade, and observe both updates without page reload.
- **SC-010**: Realtime position updates for an already-rendered security update the existing UI row in place with no duplicate row created.
- **SC-011**: `All Accounts` mode is available, loads cross-account blotters, and disables ticket creation.
- **SC-012**: Security input typeahead uses combined ticker/company labels and suppresses browser autocomplete behavior.
- **SC-013**: Account-user grid displays full names resolved from people-service (or username fallback when lookup fails).
- **SC-014**: UI smoke checks verify header title format includes active state id and `About` navigation is present.
- **SC-015**: UI smoke checks verify About page renders state id, generation timestamp, source branch, prior-state lineage summaries, and API explorer link.
- **SC-016**: Runtime startup scripts demonstrate state-mismatch detection output for matched and mismatched generated outputs, including optional regenerate mode.

## Assumptions

- Baseline scope is pre-containerized local-process runtime.
- Angular frontend is the active UI baseline.
- Local toolchains are available (`node`, `npm`, `java`, `gradle`, `dotnet`).
- Current component behavior in `system/end-to-end-flows.md`, `system/architecture.md`, and root `README.md` is the intended baseline target.
- `catalog/state-catalog.json` and generated `ci/state-metadata.json` are available inputs for state-aware UI metadata rendering.
