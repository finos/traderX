# FINOS | TraderX Sample Trading App | Trading Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

A simple application that accepts new trade requests, validates their account and security
and publishes them onto a trade feed for further processing

# How to run the application (WIP)

- Check out the source code from git
- Build it with gradlew (once the code is in place)
- ``gradlew bootRun``

# Configuration

You can use environment variables to override certain values. These are the default ones,
so no need to override them if you are happy with these values!

   $ export TRADING_SERVICE_PORT=XXXXX
   $ export ACCOUNT_SERVICE_URL=http://HOSTPORT
   $ export REFERENCE_DATA_SERVICE_URL=http://HOSTPORT
   $ export TRADE_FEED_ADDRESS=HOSTPORT

Or you can also use command line arguments:
    
   $ gradlew bootRun --args='--TRADING_SERVICE_PORT=XXXX'
   
The app by default runs on port 7070 and you can access the swagger on http://localhost:7070/swagger-ui.html

# API documentation

The API documentation is available via swagger:

http://localhost:7070/api-docs

And via UI:

http://localhost:7070/swagger-ui.html