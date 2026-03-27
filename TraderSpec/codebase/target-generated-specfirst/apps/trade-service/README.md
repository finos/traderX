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
   
The app by default runs on port `18092` and you can access the swagger on http://localhost:18092/swagger-ui.html

# API documentation

The API documentation is available via swagger:

http://localhost:18092/api-docs

And via UI:

http://localhost:18092/swagger-ui.html



## Simple Testing of Position Service`

You can run a mock of this service by installing @stoplight/prism 

This statically uses the example content in the OpenAPI spec to mock the service (you can specify `--dynamic` to let it be more creative)

```bash
# Only need to do this once for your machine
sudo npm install -g @stoplight/prism-cli
```

Run prism to mock your OpenAPI spec as follows (Specify `port` as you see fit)
```bash
prism --cors --port 18092 mock openapi.yaml
```

You can then try out your requests against the mock service as follows: (or from a browser)

```bash
curl -X 'POST' \
  'http://localhost:18092/trade/' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "security": "ADBE",
  "quantity": 200,
  "accountID": 22214,
  "side": "Buy"
}'
```