# System Requirements (Spec Kit Baseline)

## Functional Requirements

- `SYS-FR-001` The system SHALL start the baseline services in deterministic dependency order using explicit ports.
- `SYS-FR-002` The UI SHALL load all accounts at startup through account-service and render them for selection.
- `SYS-FR-003` The UI SHALL load initial trades and positions for a selected account via position-service.
- `SYS-FR-004` The UI SHALL subscribe to trade-feed account topics and render incremental trade/position updates.
- `SYS-FR-005` The system SHALL expose ticker lookup/list APIs through reference-data.
- `SYS-FR-006` The trade-service SHALL validate account and ticker before publishing new trade orders.
- `SYS-FR-007` The trade-processor SHALL persist trades, update trade state, and upsert positions in database.
- `SYS-FR-008` The account-service SHALL support account create/update and account-user mapping operations.
- `SYS-FR-009` The account-service SHALL validate users with people-service before persisting account-user mappings.
- `SYS-FR-010` The system SHALL provide health/readiness endpoints used by startup and smoke checks.
- `SYS-FR-011` The generated codebase SHALL preserve current baseline API/event contracts required for UI and service interoperability.

## Non-Functional Requirements

- `SYS-NFR-001` Baseline pre-ingress mode SHALL allow required cross-origin browser calls between UI and API ports.
- `SYS-NFR-002` Baseline runtime ports SHALL remain stable and configurable through environment variables.
- `SYS-NFR-003` Generated components SHALL be runnable on local developer workstations using language-native toolchains.
- `SYS-NFR-004` The system SHALL provide deterministic smoke-testable startup and stop scripts.
- `SYS-NFR-005` Requirements SHALL be traceable to user stories, acceptance criteria, generated components, and verification commands.
- `SYS-NFR-006` Angular UI branding assets and FINOS/TraderX identity SHALL remain intact in baseline UI generation.
- `SYS-NFR-007` Spec-first generation SHALL not require hydration from deleted legacy source trees.
