---
architecture: ../trading-system.architecture.json
---
# Trading System Flows Overview

## Load List of Accounts

    Description: Web GUI retrieves and displays the list of all trading accounts

```mermaid
sequenceDiagram
    Web GUI ->> Account Service: Web GUI requests list of accounts from Account Service
    Account Service ->> Database: Account Service queries Database for all accounts
    Database -->> Account Service: Database returns account list to Account Service
    Account Service -->> Web GUI: Account Service returns account list to Web GUI for display
```



---

## Bootstrap Trade and Position Blotter

    Description: Initialize the blotter with current trades and positions, then subscribe to live updates

```mermaid
sequenceDiagram
    Web GUI ->> Position Service: Web GUI requests trades and positions for selected account
    Position Service ->> Database: Position Service queries Database for trades and positions
    Database -->> Position Service: Database returns initial dataset to Position Service
    Position Service -->> Web GUI: Position Service returns initial data to Web GUI
    Web GUI ->> Trade Feed: Web GUI subscribes to Message Bus for live trade and position updates
    Trade Feed -->> Web GUI: Message Bus publishes trade and position updates to Web GUI
```



---

## Submit Trade Ticket
    Description: User submits a trade order with validation against reference data service and account service

```mermaid
sequenceDiagram
    Trader ->> Web GUI: Trader interacts with Web GUI to submit trade ticket
    Web GUI ->> Reference Data Service: Web GUI retrieves list of valid tickers from Reference Data Service
    Reference Data Service -->> Web GUI: Reference Data Service returns ticker list to Web GUI
    Web GUI ->> Trading Services: User submits trade request with account, ticker, side, and quantity
    Trading Services ->> Reference Data Service: Trading Service validates ticker with Reference Data Service
    Reference Data Service -->> Trading Services: Reference Data Service returns validation result to Trading Service
    Trading Services ->> Account Service: Trading Service validates account with Account Service
    Account Service -->> Trading Services: Account Service returns validation result to Trading Service
    Trading Services ->> Trade Feed: Trading Service publishes new trade event to Message Bus
    Trading Services -->> Web GUI: Trading Service returns completion response to Web GUI
```



---

## Process Trade Event

    Description: Trade Processor handles new trade events, updates database, and publishes position updates

```mermaid
sequenceDiagram
    Trade Feed ->> Trade Processor: Message Bus delivers new trade event to Trade Processor
    Trade Processor ->> Database: Trade Processor inserts trade into Database
    Trade Processor ->> Trade Feed: Trade Processor publishes account-specific trade event to Message Bus
    Trade Feed -->> Web GUI: Message Bus forwards trade event to Web GUI
    Trade Processor ->> Database: Trade Processor updates trade as executed
    Trade Processor ->> Database: Trade Processor inserts or updates position
    Trade Processor ->> Trade Feed: Trade Processor publishes trade event update to Message Bus
    Trade Feed -->> Web GUI: Message Bus forwards trade update to Web GUI
    Trade Processor ->> Trade Feed: Trade Processor publishes position event to Message Bus
    Trade Feed -->> Web GUI: Message Bus forwards position update to Web GUI
```



---

## Manage Account

    Description: Create a new trading account or update existing account information

```mermaid
sequenceDiagram
    Web GUI ->> Account Service: Web GUI sends account creation or update request to Account Service
    Account Service ->> Database: Account Service writes new or updated account information to Database
    Account Service -->> Web GUI: Account Service returns success or failure response to Web GUI
```



---

## Add User to Account

    Description: Associate users with trading accounts by searching the user directory and updating mappings

```mermaid
sequenceDiagram
    Web GUI ->> Account Service: Web GUI retrieves current list of associated people from Account Service
    Account Service ->> Database: Account Service queries Database for account-user mappings
    Database -->> Account Service: Database returns current user associations
    Account Service -->> Web GUI: Account Service returns user list to Web GUI
    Web GUI ->> People Service: Web GUI searches for users through People Service
    People Service ->> User Directory: People Service queries User Directory for matching users
    User Directory -->> People Service: User Directory returns matching records to People Service
    People Service -->> Web GUI: People Service returns search results to Web GUI
    Web GUI ->> Account Service: Web GUI requests Account Service to add selected user to account
    Account Service ->> People Service: Account Service validates username with People Service
    People Service -->> Account Service: People Service returns validation result to Account Service
    Account Service ->> Database: Account Service updates account-user mapping in Database
    Account Service -->> Web GUI: Account Service returns success or failure response to Web GUI
```



---

## Reference Data Service Bootstrap
    Description: Load ticker list from CSV file at startup and provide it to the Web GUI

```mermaid
sequenceDiagram
    Reference Data Service ->> CSV File: Reference Data Service loads CSV file at startup
    CSV File -->> Reference Data Service: CSV File returns ticker list to Reference Data Service
    Web GUI ->> Reference Data Service: Web GUI requests ticker list from Reference Data Service
    Reference Data Service -->> Web GUI: Reference Data Service returns loaded ticker data to Web GUI
```



---

