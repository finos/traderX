---
architecture: ../trading-system.architecture.json
---
## Architecture Overview
```mermaid
---
config:
  theme: base
  themeVariables:
    fontFamily: -apple-system, BlinkMacSystemFont, 'Segoe WPC', 'Segoe UI', system-ui, 'Ubuntu', sans-serif
    darkMode: false
    fontSize: 14px
    edgeLabelBackground: '#d5d7e1'
    lineColor: '#000000'
---
%%{init: {"layout": "elk", "flowchart": {"htmlLabels": false}}}%%
flowchart TB
classDef boundary fill:#e1e4f0,stroke:#204485,stroke-dasharray: 5 4,stroke-width:1px,color:#000000;
classDef node fill:#eef1ff,stroke:#007dff,stroke-width:1px,color:#000000;
classDef iface fill:#f0f0f0,stroke:#b6b6b6,stroke-width:1px,font-size:10px,color:#000000;
classDef highlight fill:#fdf7ec,stroke:#f0c060,stroke-width:1px,color:#000000;

        subgraph trading-system["Trading System"]
        direction TB
            account-service["Account Service"]:::node
            database["Database"]:::node
            people-service["People Service"]:::node
            position-service["Position Service"]:::node
            reference-data-service["Reference Data Service"]:::node
            messagebus["Trade Feed"]:::node
            trade-processor["Trade Processor"]:::node
            trading-services["Trading Services"]:::node
            web-gui["Web GUI"]:::node
        end
        class trading-system boundary

    reference-data-csv["CSV File"]:::node
    trader["Trader"]:::node
    user-directory["User Directory"]:::node

    trader -->|Manage Accounts, Execute Trades, View Trade Status / Positions| web-gui
    web-gui -->|Creates/Updates Accounts. Gets list of accounts| account-service
    web-gui -->|Loads positions for account| position-service
    web-gui -->|Looks up securities to assist with creating a trade ticket| reference-data-service
    web-gui -->|Creates new Trades and Cancel existing trades| trading-services
    web-gui -->|Looks up people data based on typeahead from GUI| people-service
    trading-services -->|Validates securities when creating trades| reference-data-service
    trading-services -->|Validates accounts when creating trades| account-service
    people-service -->|Looks up people data| user-directory
    reference-data-service -->|Loads ticker symbols from CSV file at startup| reference-data-csv
    account-service -->|CRUD operations around accounts.| database
    account-service -->|Validates People IDs when creating/modifying accounts| people-service
    position-service -->|Looks up default positions for a given account| database
    trade-processor -->|Looks up current positions when bootstraping state, persist trade state and position state| database
    trading-services -->|Publishes updates to trades and positions after persisting in the DB| messagebus
    messagebus -->|Processes incoming trade requests, persist, and publish updates| trade-processor
    trade-processor -->|Processes incoming trade requests, persist, and publish updates| messagebus
    web-gui -->|Subscribes to trade/position updates feed for currently viewed account| messagebus



```



## Single Service
```mermaid
---
config:
  theme: base
  themeVariables:
    fontFamily: -apple-system, BlinkMacSystemFont, 'Segoe WPC', 'Segoe UI', system-ui, 'Ubuntu', sans-serif
    darkMode: false
    fontSize: 14px
    edgeLabelBackground: '#d5d7e1'
    lineColor: '#000000'
---
%%{init: {"layout": "elk", "flowchart": {"htmlLabels": false}}}%%
flowchart TB
classDef boundary fill:#e1e4f0,stroke:#204485,stroke-dasharray: 5 4,stroke-width:1px,color:#000000;
classDef node fill:#eef1ff,stroke:#007dff,stroke-width:1px,color:#000000;
classDef iface fill:#f0f0f0,stroke:#b6b6b6,stroke-width:1px,font-size:10px,color:#000000;
classDef highlight fill:#fdf7ec,stroke:#f0c060,stroke-width:1px,color:#000000;

        subgraph trading-system["Trading System"]
        direction TB
            reference-data-service["Reference Data Service"]:::node
            trading-services["Trading Services"]:::node
            web-gui["Web GUI"]:::node
        end
        class trading-system boundary

    reference-data-csv["CSV File"]:::node

    web-gui -->|Looks up securities to assist with creating a trade ticket| reference-data-service
    web-gui -->|Creates new Trades and Cancel existing trades| trading-services
    trading-services -->|Validates securities when creating trades| reference-data-service
    reference-data-service -->|Loads ticker symbols from CSV file at startup| reference-data-csv


    class reference-data-service highlight

```

<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>reference-data-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Reference Data Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides REST API to securities reference data</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>

## Multiple Services No Database
```mermaid
---
config:
  theme: base
  themeVariables:
    fontFamily: -apple-system, BlinkMacSystemFont, 'Segoe WPC', 'Segoe UI', system-ui, 'Ubuntu', sans-serif
    darkMode: false
    fontSize: 14px
    edgeLabelBackground: '#d5d7e1'
    lineColor: '#000000'
---
%%{init: {"layout": "elk", "flowchart": {"htmlLabels": false}}}%%
flowchart TB
classDef boundary fill:#e1e4f0,stroke:#204485,stroke-dasharray: 5 4,stroke-width:1px,color:#000000;
classDef node fill:#eef1ff,stroke:#007dff,stroke-width:1px,color:#000000;
classDef iface fill:#f0f0f0,stroke:#b6b6b6,stroke-width:1px,font-size:10px,color:#000000;
classDef highlight fill:#fdf7ec,stroke:#f0c060,stroke-width:1px,color:#000000;

        subgraph trading-system["Trading System"]
        direction TB
            account-service["Account Service"]:::node
            database["Database"]:::node
            people-service["People Service"]:::node
            position-service["Position Service"]:::node
            reference-data-service["Reference Data Service"]:::node
            messagebus["Trade Feed"]:::node
            trading-services["Trading Services"]:::node
            web-gui["Web GUI"]:::node
        end
        class trading-system boundary

    reference-data-csv["CSV File"]:::node
    trader["Trader"]:::node
    user-directory["User Directory"]:::node

    trader -->|Manage Accounts, Execute Trades, View Trade Status / Positions| web-gui
    web-gui -->|Creates/Updates Accounts. Gets list of accounts| account-service
    web-gui -->|Loads positions for account| position-service
    web-gui -->|Looks up securities to assist with creating a trade ticket| reference-data-service
    web-gui -->|Creates new Trades and Cancel existing trades| trading-services
    web-gui -->|Looks up people data based on typeahead from GUI| people-service
    trading-services -->|Validates securities when creating trades| reference-data-service
    trading-services -->|Validates accounts when creating trades| account-service
    people-service -->|Looks up people data| user-directory
    reference-data-service -->|Loads ticker symbols from CSV file at startup| reference-data-csv
    account-service -->|CRUD operations around accounts.| database
    account-service -->|Validates People IDs when creating/modifying accounts| people-service
    position-service -->|Looks up default positions for a given account| database
    trading-services -->|Publishes updates to trades and positions after persisting in the DB| messagebus
    web-gui -->|Subscribes to trade/position updates feed for currently viewed account| messagebus


    class reference-data-service highlight
    class web-gui highlight
    class account-service highlight
    class people-service highlight

```

<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>reference-data-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Reference Data Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides REST API to securities reference data</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>web-gui</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Web GUI</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts and book trades.</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>webclient</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                HTML and JavaScript and NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>account-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Account Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                Java and Spring Boot
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>people-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>People Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides user details</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                .NET Core
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>

## Multiple Services With Database
```mermaid
---
config:
  theme: base
  themeVariables:
    fontFamily: -apple-system, BlinkMacSystemFont, 'Segoe WPC', 'Segoe UI', system-ui, 'Ubuntu', sans-serif
    darkMode: false
    fontSize: 14px
    edgeLabelBackground: '#d5d7e1'
    lineColor: '#000000'
---
%%{init: {"layout": "elk", "flowchart": {"htmlLabels": false}}}%%
flowchart TB
classDef boundary fill:#e1e4f0,stroke:#204485,stroke-dasharray: 5 4,stroke-width:1px,color:#000000;
classDef node fill:#eef1ff,stroke:#007dff,stroke-width:1px,color:#000000;
classDef iface fill:#f0f0f0,stroke:#b6b6b6,stroke-width:1px,font-size:10px,color:#000000;
classDef highlight fill:#fdf7ec,stroke:#f0c060,stroke-width:1px,color:#000000;

        subgraph trading-system["Trading System"]
        direction TB
            account-service["Account Service"]:::node
            database["Database"]:::node
            people-service["People Service"]:::node
            position-service["Position Service"]:::node
            reference-data-service["Reference Data Service"]:::node
            messagebus["Trade Feed"]:::node
            trade-processor["Trade Processor"]:::node
            trading-services["Trading Services"]:::node
            web-gui["Web GUI"]:::node
        end
        class trading-system boundary

    reference-data-csv["CSV File"]:::node
    trader["Trader"]:::node
    user-directory["User Directory"]:::node

    trader -->|Manage Accounts, Execute Trades, View Trade Status / Positions| web-gui
    web-gui -->|Creates/Updates Accounts. Gets list of accounts| account-service
    web-gui -->|Loads positions for account| position-service
    web-gui -->|Looks up securities to assist with creating a trade ticket| reference-data-service
    web-gui -->|Creates new Trades and Cancel existing trades| trading-services
    web-gui -->|Looks up people data based on typeahead from GUI| people-service
    trading-services -->|Validates securities when creating trades| reference-data-service
    trading-services -->|Validates accounts when creating trades| account-service
    people-service -->|Looks up people data| user-directory
    reference-data-service -->|Loads ticker symbols from CSV file at startup| reference-data-csv
    account-service -->|CRUD operations around accounts.| database
    account-service -->|Validates People IDs when creating/modifying accounts| people-service
    position-service -->|Looks up default positions for a given account| database
    trade-processor -->|Looks up current positions when bootstraping state, persist trade state and position state| database
    trading-services -->|Publishes updates to trades and positions after persisting in the DB| messagebus
    messagebus -->|Processes incoming trade requests, persist, and publish updates| trade-processor
    trade-processor -->|Processes incoming trade requests, persist, and publish updates| messagebus
    web-gui -->|Subscribes to trade/position updates feed for currently viewed account| messagebus


    class reference-data-service highlight
    class web-gui highlight
    class account-service highlight
    class people-service highlight
    class database highlight

```

<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>reference-data-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Reference Data Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides REST API to securities reference data</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>web-gui</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Web GUI</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts and book trades.</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>webclient</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                HTML and JavaScript and NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>account-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Account Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                Java and Spring Boot
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>people-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>People Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides user details</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                .NET Core
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>database</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Database</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Stores account, trade, and position state.</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>database</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                H2 Standalone
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>

## Multiple Services With Trade Feed
```mermaid
---
config:
  theme: base
  themeVariables:
    fontFamily: -apple-system, BlinkMacSystemFont, 'Segoe WPC', 'Segoe UI', system-ui, 'Ubuntu', sans-serif
    darkMode: false
    fontSize: 14px
    edgeLabelBackground: '#d5d7e1'
    lineColor: '#000000'
---
%%{init: {"layout": "elk", "flowchart": {"htmlLabels": false}}}%%
flowchart TB
classDef boundary fill:#e1e4f0,stroke:#204485,stroke-dasharray: 5 4,stroke-width:1px,color:#000000;
classDef node fill:#eef1ff,stroke:#007dff,stroke-width:1px,color:#000000;
classDef iface fill:#f0f0f0,stroke:#b6b6b6,stroke-width:1px,font-size:10px,color:#000000;
classDef highlight fill:#fdf7ec,stroke:#f0c060,stroke-width:1px,color:#000000;

        subgraph trading-system["Trading System"]
        direction TB
            account-service["Account Service"]:::node
            database["Database"]:::node
            people-service["People Service"]:::node
            position-service["Position Service"]:::node
            reference-data-service["Reference Data Service"]:::node
            messagebus["Trade Feed"]:::node
            trade-processor["Trade Processor"]:::node
            trading-services["Trading Services"]:::node
            web-gui["Web GUI"]:::node
        end
        class trading-system boundary

    reference-data-csv["CSV File"]:::node
    trader["Trader"]:::node
    user-directory["User Directory"]:::node

    trader -->|Manage Accounts, Execute Trades, View Trade Status / Positions| web-gui
    web-gui -->|Creates/Updates Accounts. Gets list of accounts| account-service
    web-gui -->|Loads positions for account| position-service
    web-gui -->|Looks up securities to assist with creating a trade ticket| reference-data-service
    web-gui -->|Creates new Trades and Cancel existing trades| trading-services
    web-gui -->|Looks up people data based on typeahead from GUI| people-service
    trading-services -->|Validates securities when creating trades| reference-data-service
    trading-services -->|Validates accounts when creating trades| account-service
    people-service -->|Looks up people data| user-directory
    reference-data-service -->|Loads ticker symbols from CSV file at startup| reference-data-csv
    account-service -->|CRUD operations around accounts.| database
    account-service -->|Validates People IDs when creating/modifying accounts| people-service
    position-service -->|Looks up default positions for a given account| database
    trade-processor -->|Looks up current positions when bootstraping state, persist trade state and position state| database
    trading-services -->|Publishes updates to trades and positions after persisting in the DB| messagebus
    messagebus -->|Processes incoming trade requests, persist, and publish updates| trade-processor
    trade-processor -->|Processes incoming trade requests, persist, and publish updates| messagebus
    web-gui -->|Subscribes to trade/position updates feed for currently viewed account| messagebus


    class reference-data-service highlight
    class web-gui highlight
    class account-service highlight
    class people-service highlight
    class database highlight
    class messagebus highlight

```

<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>reference-data-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Reference Data Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides REST API to securities reference data</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>web-gui</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Web GUI</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts and book trades.</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>webclient</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                HTML and JavaScript and NodeJS
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>account-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Account Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Allows employees to manage accounts</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                Java and Spring Boot
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>people-service</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>People Service</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Provides user details</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                .NET Core
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>database</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Database</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Stores account, trade, and position state.</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>database</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                H2 Standalone
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>
<div class="table-container">
    <table>
        <tbody>
        <tr>
            <th>Unique Id</th>
            <td>messagebus</td>
        </tr>
        <tr>
            <th>Name</th>
            <td>Trade Feed</td>
        </tr>
        <tr>
            <th>Description</th>
            <td>Message bus for streaming updates to trades and positions</td>
        </tr>
        <tr>
            <th>Node Type</th>
            <td>service</td>
        </tr>
        <tr>
            <th>Metadata</th>
            <td>
                <table class="nested-table">
                        <tbody>
                        <tr>
                            <td><b>Technology</b></td>
                            <td>
                                SocketIO
                                    </td>
                        </tr>
                        </tbody>
                    </table>        </td>
        </tr>
        </tbody>
    </table>
</div>

