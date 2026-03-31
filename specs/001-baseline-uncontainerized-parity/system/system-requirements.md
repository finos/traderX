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
- `SYS-FR-012` Submitting a valid trade through trade-service SHALL produce realtime account-scoped trade and position websocket updates consumable without page refresh.
- `SYS-FR-013` The UI position blotter SHALL upsert realtime position updates by security key so existing rows are updated in place and duplicates are not created.
- `SYS-FR-014` The UI SHALL provide an `All Accounts` selection that loads aggregated trades and merged positions across all known accounts.
- `SYS-FR-015` In `All Accounts` mode, the UI SHALL disable trade-ticket creation and display explanatory guidance.
- `SYS-FR-016` Security entry in trade ticket SHALL use typeahead matching by combined ticker/company label and disable browser autocomplete.
- `SYS-FR-017` Account administration UI SHALL resolve usernames to people-service full names for account-user display with fallback to username on lookup failure.

## Non-Functional Requirements

- `SYS-NFR-001` Baseline pre-ingress mode SHALL allow required cross-origin browser calls between UI and API ports.
- `SYS-NFR-002` Baseline runtime ports SHALL remain stable and configurable through environment variables.
- `SYS-NFR-003` Generated components SHALL be runnable on local developer workstations using language-native toolchains.
- `SYS-NFR-004` The system SHALL provide deterministic smoke-testable startup and stop scripts.
- `SYS-NFR-005` Requirements SHALL be traceable to user stories, acceptance criteria, generated components, and verification commands.
- `SYS-NFR-006` Angular UI branding assets and FINOS/TraderX identity SHALL remain intact in baseline UI generation.
- `SYS-NFR-007` Spec-first generation SHALL not require hydration from deleted legacy source trees.
- `SYS-NFR-008` Trade and position blotters SHALL keep responsive readability through side-by-side layout with wrap and minimum pane width constraints.
