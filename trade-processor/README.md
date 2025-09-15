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

   `export TRADE_PROCESSOR_SERVICE_PORT=18091`

Or you can use command line arguments:
    
   $ gradlew bootRun --args='--server.port=18091'
   
The app by default runs on port 18091

## Trade Feed Location

You can either specify `TRADE_FEED_ADDRESS` as an environment variable (should be a URL in the current SocketIO implementation) or specify the app property per below

To specify the host and the port for the TradeFeed instance to subscribe to use the `trade.feed.address` property using one of the ways describe above, like

   $ gradlew bootRun --args='--trade.feed.address=http://localhost:18086

## Database settings

To specify the database properties, the following properties should be used

    spring.datasource.url=jdbc:postgresql://localhost:5432/traderx
    spring.datasource.username=sa
    spring.datasource.password=sa


You can see all configuration details in [src/main/resources/application.properties](application.properties)