# Spec Kit Component: account-service

## Responsibilities

- Return account list/details for UI workflows.
- Create/update accounts.
- Maintain account-user mappings with people-service validation.

## Covered Flows

- `STARTUP`
- `F1`
- `F3`
- `F5`
- `F6`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-002`, `SYS-FR-006`, `SYS-FR-008`, `SYS-FR-009`, `SYS-FR-011`
- `SYS-NFR-001`, `SYS-NFR-005`

## Contracts

- `specs/001-baseline-uncontainerized-parity/contracts/account-service/openapi.yaml`

## Verification

- `scripts/test-account-service-overlay.sh`
