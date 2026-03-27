# 08 Requirements Traceability Matrix

| Requirement | Primary Components | Interfaces / Topics | Verification Target |
|---|---|---|---|
| FR-001 Account Lifecycle | `account-service`, `web-front-end-angular` | `/account/`, `/accountuser/` | account create/list and account-user create/list checks |
| FR-002 Trade Capture and Validation | `trade-service`, `reference-data`, `account-service` | `POST /trade/`, `/stocks/{ticker}`, `/account/{id}` | valid trade accepted, invalid account/ticker rejected |
| FR-003 Trade Processing and Position Updates | `trade-processor`, `trade-feed`, `position-service` | `/trades`, `/accounts/{id}/trades`, `/accounts/{id}/positions` | state transitions + live update propagation |
| FR-004 Read APIs for Trades and Positions | `position-service`, `web-front-end-angular` | `/trades/{accountId}`, `/positions/{accountId}` | blotter initial load correctness |
| FR-005 Reference Data + People Directory | `reference-data`, `people-service`, `account-service`, UI | `/stocks*`, `/People/*` | symbol and people lookup UX |
| FR-006 Primary UI Workflow | `web-front-end-angular`, backend services | trade ticket + blotter interactions | end-to-end create + live update flow |
| FR-007 Health and Operability | all services | service health endpoints | startup + health smoke checks |

## Technical Spec Trace

- Component technical matrix: `TraderSpec/catalog/component-spec.csv`
- API contracts: `* /openapi.yaml` listed in `04-interface-contracts-baseline.md`
- UI behavior: `07-ui-requirements-detailed.md`
