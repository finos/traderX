# Spec Kit Component: position-service

## Responsibilities

- Provide trades and positions by account for blotter bootstrap and refresh.
- Expose health endpoints used in startup validation.

## Covered Flows

- `STARTUP`
- `F2`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-003`, `SYS-FR-011`

## Contracts

- `TraderSpec/speckit/contracts/position-service/openapi.yaml`

## Verification

- `TraderSpec/codebase/scripts/test-position-service-overlay.sh`
