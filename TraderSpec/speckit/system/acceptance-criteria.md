# Acceptance Criteria (Spec Kit Baseline)

- `AC-001` Given baseline startup scripts are run, when dependencies are available, then all baseline services reach ready state on expected ports.
- `AC-002` Given the UI loads, when account list is requested, then account-service returns account data and UI renders options.
- `AC-003` Given an account is selected, when blotter bootstrap executes, then position-service returns trades/positions and UI subscribes to account topics.
- `AC-004` Given a valid trade ticket, when submitted to trade-service, then ticker/account validation succeeds and a new trade event is published.
- `AC-005` Given a new trade event on trade-feed, when trade-processor handles it, then trade state and positions are persisted and account updates are published.
- `AC-006` Given account create/update input, when submitted to account-service, then account data is persisted and retrieval reflects the change.
- `AC-007` Given account-user mapping input, when username is validated by people-service, then mapping persists; unknown usernames are rejected.
- `AC-008` Given browser-origin requests in pre-ingress mode, when UI calls service APIs, then CORS headers allow required requests.
- `AC-009` Given generated components are rebuilt from Spec Kit inputs, when smoke tests run, then they pass without hydrating deleted legacy component trees.
