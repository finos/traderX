# Spec Kit Component: people-service

## Responsibilities

- Provide person lookup and matching endpoints.
- Validate usernames for account-user association workflows.
- Support baseline pre-ingress CORS behavior.

## Covered Flows

- `STARTUP`
- `F6`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-009`, `SYS-FR-011`
- `SYS-NFR-001`

## Contracts

- `specs/001-baseline-uncontainerized-parity/contracts/people-service/openapi.yaml`

## Verification

- `TraderSpec/codebase/scripts/test-people-service-overlay.sh`
