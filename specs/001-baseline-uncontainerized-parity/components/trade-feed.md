# Spec Kit Component: trade-feed

## Responsibilities

- Provide pub/sub message bus for trade and position event topics.
- Maintain command compatibility for subscribe/unsubscribe/publish flows.

## Covered Flows

- `STARTUP`
- `F2`
- `F4`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-004`
- `SYS-NFR-004`

## Verification

- `scripts/test-trade-feed-overlay.sh`
