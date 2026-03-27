# Spec Kit Component: trade-processor

## Responsibilities

- Consume new trade events.
- Persist trade state transitions and position deltas.
- Publish account-scoped trade and position update events.

## Covered Flows

- `STARTUP`
- `F4`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-007`, `SYS-FR-011`

## Contracts

- `TraderSpec/speckit/contracts/trade-processor/openapi.yaml`

## Verification

- `TraderSpec/codebase/scripts/test-trade-processor-overlay.sh`
