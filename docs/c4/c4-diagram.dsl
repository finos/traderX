workspace "FINOS TraderX Sample Application" "An example distributed system in finance." {

    model {
       trader = person "Trader" "Managing Accounts and Creating Trades" "Trader"

        tradingSystem = softwaresystem "Simple Trading System" "Allows employees to create accounts, and execute trades and view positions on these accounts." "Spring Boot Application" {
            webFrontend = container "Web GUI" "Allows employees to manage accounts and book trades." "HTML and JavaScript and NodeJS"
            peopleService = container "People Service" "Provides user details" ".NET Core"
            accountService = container "Account Service" "Allows employees to manage accounts" "Java and Spring Boot"
            positionService = container "Position Service" "View all trades and positions for an account" "Python and Flask"
            refDataService = container "Reference Data Service" "Provides REST API to securities reference data" "NodeJS"
            tradingService = container "Trading Services" "Allows employees create and update trades" "Java and Spring Boot"
            messagebus = container "Trade Feed" "Message bus for streaming updates to trades and positions" "Topic-based Publish-subscribe engine" "SocketIO"
            tradeProcessor = container "Trade Processor" "Process incoming trade requests, settle, and persist" "Java and Spring Boot"
            database = container "Database" "Stores account, trade, and position state." "Relational database schema" "H2 Standalone"
        }
            userDirectory = softwaresystem "User Directory" "Golden source of User Data"  "External"

        webFrontend -> peopleService "Looks up people data based on typeahead from GUI" "REST/JSON/HTTP"
        webFrontend -> refDataService "Looks up securities to assist with creating a trade ticket" "REST/JSON/HTTP"
        peopleService -> userDirectory "Looks up people data" "LDAP"
        webFrontend -> tradingService "Creatse new Trades and Cancel existing trades" "REST/JSON/HTTP"
        tradingService -> messagebus "Publishes updates to trades and positions after persisting in the DB" "JSON/HTTP" 
        tradeProcessor -> messagebus "Processes incoming trade requests, persist, and publish updates" "SocketIO/JSON"
        webFrontend -> accountService "Creates/Updates Accounts. Gets list of accounts" "REST/JSON/HTTP"
        webFrontend -> positionService "Loads positions for account" "REST/JSON/HTTP"
        webFrontend -> positionService "Loads trades for account" "REST/JSON/HTTP"
        accountService -> database "CRUD operations around accounts." "SQL"
        positionService -> database "Looks up default positions for a given account" "SQL"
        positionService -> database "Looks up all trades for a given account" "SQL"

        webFrontend -> messagebus "Subscribes to trade/position updates feed for currently viewed account" "WebSocket/JSON/WS"
        tradeProcessor -> database "Looks up current positions when bootstraping state, persist trade state and position state" "SQL"
        accountService -> peopleService "Validates People IDs when creating/modifying accounts" "REST/JSON/HTTP"
        tradingService -> accountService "Validates accounts when creating trades" "REST/JSON/HTTP"
        tradingService -> refDataService "Validates securities when creating trades" "REST/JSON/HTTP"
        
        trader  -> webFrontend "Manage Accounts"
        trader  -> webFrontend "Execute Trades"
        trader  -> webFrontend "View Trade Status / Positions"

    }
       
    views {
        
        container  tradingSystem "single-service" {
            include refDataService
            autoLayout
        }
         
        container  tradingSystem "multiple-services-no-db" {
            include refDataService webFrontend accountService peopleService userDirectory
            
        }
        
        container  tradingSystem "multiple-services-db-no-messaging" {
            include refDataService webFrontend accountService peopleService userDirectory database positionService
            
        }
        
        container  tradingSystem "multiple-services-no-async" {
            include refDataService webFrontend accountService peopleService userDirectory database positionService messagebus
            
        }
        
        container  tradingSystem "full-system" {
            include *
            
        }

    
     styles {
            element "Person" {
                color #ffffff
                background #1168bd
                fontSize 22
                shape Person
            }
            element "Customer" {
                background #08427b
            }
            element "Bank Staff" {
                background #999999
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
             element "RecordsMgmt" {
                background #008080
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Web Browser" {
                shape WebBrowser
            }
            element "Mobile App" {
                shape MobileDeviceLandscape
            }
            element "Content Repository" {
                shape Cylinder
            }
             element "Database" {
                shape Cylinder
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
           }
            }
}
