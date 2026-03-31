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
- `AC-010` Given a websocket client subscribed to account trade and position topics, when a valid trade is submitted via trade-service, then both incremental updates are received without page refresh.
- `AC-011` Given an existing position row for a security is already rendered, when a realtime websocket update arrives for that same security, then the existing row is updated in place and no duplicate row is added.
- `AC-012` Given `All Accounts` is selected, when blotters load and updates stream, then trades are shown cross-account with account display and positions are merged by security.
- `AC-013` Given `All Accounts` mode is active, when user attempts to create a trade ticket, then creation is disabled and guidance is shown.
- `AC-014` Given user enters security text in trade ticket, when typeahead suggestions appear, then combined ticker/company labels are used and browser autocomplete is suppressed.
- `AC-015` Given account-user mappings are displayed, when people-service lookup succeeds, then full names are shown; on lookup failure, username fallback is shown.
- `AC-016` Given viewport constraints vary, when trade and position blotters render, then layout wraps while preserving minimum pane width for readability.
