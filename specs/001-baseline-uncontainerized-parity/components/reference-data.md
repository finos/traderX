# Spec Kit Component: reference-data

## Responsibilities

- Serve ticker universe (`/stocks`, `/stocks/{ticker}`) for trade validation and UI selection.
- Support baseline pre-ingress CORS behavior for cross-port browser calls.

## Covered Flows

- `STARTUP`
- `F3`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-005`, `SYS-FR-011`
- `SYS-NFR-001`

## Contracts

- `specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml`

## Verification

- `TraderSpec/codebase/scripts/test-reference-data-overlay.sh`
