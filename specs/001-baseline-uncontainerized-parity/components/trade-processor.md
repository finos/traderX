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

- `specs/001-baseline-uncontainerized-parity/contracts/trade-processor/openapi.yaml`

## Verification

- `scripts/test-trade-processor-overlay.sh`

## Commit boundary (#461)

Both baseline and pricing implementations register success notifications with the
shared CommittedTradeEvents helper inside the Spring booking transaction. The
helper captures booking values and publishes only in afterCommit, attempts both
topics independently, and contains checked/unchecked notification failures. Direct
nontransactional invocation fails before repository writes. Database failure and
post-commit delivery failure must not share a retry/rebooking path.
