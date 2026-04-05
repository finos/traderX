# Data Model: Observability with LGTM on Compose

## Scope

This state introduces no business data model changes relative to `003-containerized-compose-runtime`.

## Entity Changes

- Added: none.
- Changed: none.
- Removed: none.

## Compatibility Notes

- Observability introduces operational data streams (metrics/logs/traces) only.
- Domain entities (`Account`, `Trade`, `Position`, etc.) and API payloads remain unchanged.

## Traceability

- Traceability is recorded in NFR entries and smoke tests for observability endpoints/dashboards.
