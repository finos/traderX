# Spec Kit Component: trade-service

## Responsibilities

- Accept new trade orders from UI.
- Validate account and ticker with dependent services.
- Publish valid trade orders to trade-feed for downstream processing.

## Covered Flows

- `STARTUP`
- `F3`

## Requirement Coverage

- `SYS-FR-001`, `SYS-FR-006`, `SYS-FR-010`, `SYS-FR-011`
- `SYS-NFR-007`

## Contracts

- `specs/001-baseline-uncontainerized-parity/contracts/trade-service/openapi.yaml`

## Verification

- `scripts/test-trade-service-overlay.sh`
