---
title: Sequence Diagrams and Flows
sidebar_label: Sequence Diagrams
slug: flows
---

## Sequence Diagrams

The following is a list of sequence diagrams which will help illustrate the flows which take place in this system.  For an overview of the system, be sure to look at the [Overview](./overview.md)


## 1: Load List of Accounts 

This takes place when the GUI initially loads. A list of accounts is populated into a drop down for the user to select which account to trade on.

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
## 2: Bootstrapping the Trade and Position Blotter

Once a user selects an account to trade on, the initial trade history and current positions are populated into a trade and position blotter respectively, after which future updates are streamed from the trade feed directly to the GUI. 

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant P as PositionService
    participant F as TradeFeed
    participant D as Database
    
    W->>P: Load Trades and Positions (acc)
    P->>D: Query Trades,Positions for Account
    P->>W: Return Trades and Positions for Account
    W->>F: Subscribe to Trade,Position updates (accounts/$id/trades) (accounts/$id/positions)
    F->>W: Publish Trade,Position Updates
```

## 3: Submitting a Trade Ticket

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant R as RefDataService
    participant T as TradeService
    participant A as AccountService
    participant F as TradeFeed 

    W->>R: Load ticker list 
    R->>W: Return ticker list
    W->>T: Submit trade (acct,ticker,side,qty)
    T->>R: Validate Ticker
    T->>A: Validate Account Number
    T->>F: Publish new Trade Event (trades/new)
    T->>W: Trade Submission Complete
```

## 4: Trade Processing

Trade processing here is meant to simulate any ‘black box’ downstream handling of new trade events. This is the current flow in the sample application. One could easily add random behavior, delays, rejections, etc, to the processor to make this example more interesting.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant F as TradeFeed
    participant TP as TradeProcessor
    participant D as Database

    F->>TP: New Trade Event (trades/new)
    TP->>D: Insert New Trade
    TP->>F: Publish New TradeEvent (accounts/$id/trades)
    F->>W: New Trade Created
    TP->>D: Update Trade as Executed
    TP->>D: Insert or Update Position (account, ticker, quantity)
    TP->>F: Publish TradeEvent update (accounts/$id/trades)
    F->>W: Trade Updated
    TP->>F: Publish PositionEvent (accounts/$id/positions)
    F->>W: Position Updated
```

## 5: Add/Update Account

Accounts are the entities that contain trades/positions. The web GUI supports creating and updating accounts.

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant A as AccountService
    participant D as Database

    W->>A: Submit Account create or update
    A->>D: Insert or update account row
    A->>W: Return success/failure status
```

## 6: Add/Update Users to Account

Users can be associated with accounts, for future entitlements implementation purposes. Multiple users can be associated with multiple accounts (many-to-many relationship)

```mermaid
sequenceDiagram
    participant W as WebGUI
    participant A as AccountService
    participant D as Database
    participant PS as PeopleService
    participant L as UserDirectory

    W->>A: Load current list of people for account
    A->>D: Load List of account users
    W->>PS: Lookup user to add, by name
    PS->>L: Query LDAP for People records
    L->>PS: Return people records
    PS->>W: Return search results
    W->>A: Add User to Account
    A->>PS: Validate Username
    A->>D: Insert/Update Account-User Mapping
    A->>W: Return success/failure status
```
