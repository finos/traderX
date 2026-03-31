# End-to-End Flows (State 001 Baseline)

This file is the canonical flow source for `001-baseline-uncontainerized-parity`.

<a id="F1"></a>
<a id="f1-load-accounts-on-initial-ui-load"></a>
## F1: Load Accounts On Initial UI Load

On initial UI load, account-service returns all available accounts for selection.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant A as AccountService
    participant D as Database
    
    W->>A: Load List of Accounts
    A->>D: Query for all Accounts
    D->>A: Return result set
    A->>W: Return list of accounts
```

<a id="F2"></a>
<a id="f2-bootstrap-trade--position-blotters"></a>
## F2: Bootstrap Trade + Position Blotters

After account selection, the UI loads initial trades/positions and subscribes for incremental updates.

In `All Accounts` mode, trades are loaded cross-account and positions are merged by security; trade ticket creation is disabled.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant P as PositionService
    participant F as TradeFeed
    participant D as Database
    
    W->>P: Load Trades and Positions (account)
    P->>D: Query Trades and Positions for Account
    P->>W: Return Trades and Positions for Account
    W->>F: Subscribe account topics (trades, positions)
    F->>W: Publish Trade and Position Updates
```

<a id="F3"></a>
<a id="f3-submit-trade-ticket"></a>
## F3: Submit Trade Ticket

Trade-service validates ticker and account before publishing to trade-feed.

Trade ticket security entry uses ticker/company typeahead with browser autocomplete disabled.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant R as RefDataService
    participant T as TradeService
    participant A as AccountService
    participant F as TradeFeed

    W->>R: Load ticker list
    R->>W: Return ticker list
    W->>T: Submit trade (account, ticker, side, qty)
    T->>R: Validate Ticker
    T->>A: Validate Account Number
    T->>F: Publish new Trade Event (trades/new)
    T->>W: Trade Submission Complete
```

<a id="F4"></a>
<a id="f4-process-trade-events"></a>
## F4: Process Trade Events

Trade-processor consumes new trade events, updates persistence, and publishes updates.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant F as TradeFeed
    participant TP as TradeProcessor
    participant D as Database

    F->>TP: New Trade Event (trades/new)
    TP->>D: Insert New Trade
    TP->>F: Publish TradeEvent (accounts/{id}/trades)
    F->>W: New Trade Created
    TP->>D: Update Trade as Executed
    TP->>D: Insert or Update Position (account, ticker, quantity)
    TP->>F: Publish TradeEvent update (accounts/{id}/trades)
    F->>W: Trade Updated
    TP->>F: Publish PositionEvent (accounts/{id}/positions)
    F->>W: Position Updated
```

<a id="F5"></a>
<a id="f5-addupdate-account"></a>
## F5: Add/Update Account

Account-service handles account persistence for account administration flows.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant A as AccountService
    participant D as Database

    W->>A: Submit Account create or update
    A->>D: Insert or update account row
    A->>W: Return success/failure status
```

<a id="F6"></a>
<a id="f6-addupdate-account-users"></a>
## F6: Add/Update Account Users

Account user mappings require people-service validation before persistence.

Account-user display in UI resolves usernames to `fullName` via people-service lookup.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant A as AccountService
    participant D as Database
    participant PS as PeopleService
    participant L as UserDirectory

    W->>A: Load current account-user mappings
    A->>D: Query account-user mappings
    W->>PS: Search user by name/logon
    PS->>L: Query directory
    L->>PS: Return people records
    PS->>W: Return search results
    W->>A: Add user to account
    A->>PS: Validate username
    A->>D: Insert/Update account-user mapping
    A->>W: Return success/failure status
```

## Startup Dependency Flow (Operational)

Startup order is governed by runtime catalog and scripts:

`database -> reference-data -> trade-feed -> people-service -> account-service -> position-service -> trade-processor -> trade-service -> web-front-end-angular`
