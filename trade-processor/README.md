# FINOS | TraderX Sample Trading App | Trade Processor

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

# trade-processor

A simple application that subscribes to trade-feed pubsub engine, and 'processes' trades. This initially stores them in the database as pending trades and marks them as processed, reporting each phase change on thei appropriate trade-feed as a notification. As trades are settled, it also recalculates any position changes and persists and broadcasts those changes as well.
 
# How to run the application (WIP)

- Check out the source code from git
- change any ports needed
- ``gradlew bootRun``

# Configuration

The easiest way to reconfigure the application is by editing properties in:

    `src/main/resources/application.properties`

Alternatively you can use environment variables to override certain values:

   `export server.port=8089`

Or you can use command line arguments:
    
   $ gradlew bootRun --args='--server.port=8888'
   
The app by default runs on port 8089

## Trade Feed Location

To specify the host and the port for the TradeFeed instance to subscribe to use the `tradeFeedAddress` property using one of the ways describe above, like

   $ gradlew bootRun --args='--tradeFeedAddress=icompile12.heathrow.ms.com:8888'

## Database settings

To specify the database properties, the following properties should be used

    spring.datasource.url=jdbc:h2:tcp://localhost:8082/test
    spring.datasource.username=sa
    spring.datasource.password=sa
