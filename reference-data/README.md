# FINOS | TraderX Sample Trading App | Reference Data Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The Reference Data service provides a list of stock tickers and their associated company names via a RESTful interface.

## Prerequisites

This project assumes that your environment is already configured to use node and npm

By default this will run the application on localhost, port 18085, however the hostname and port can be modified by the following environment variables:

| Environment Variable Name  | Default Value    |
| -------------------------  | ---------------- |
| REFERENCE_DATA_SERVICE_PORT| 18085             |
| HOSTNAME                   | localhost        |


## Installation

```bash
$ npm install
```

## Running the app

If you are developing the Reference Data service you can use the **start:dev** script instead. This runs with file
watchers that will automatically rebuild and redeploy the application when the code changes:

```bash
# development
$ npm run start

# watch mode
$ npm run start:dev

# production mode
$ npm run start:prod
```



##  Testing

```bash
# unit tests
$ npm run test

# e2e tests
$ npm run test:e2e

# test coverage
$ npm run test:cov
```


## Accessing the Reference Data service

Assuming the Reference Data service is running from the default location, otherwise modify the hostname and/or port
accordingly, then the following links are available:
 - http://localhost:18085/api/ - the OpenAPI UI
 - http://localhost:18085/stocks - the reference data
 - http://localhost:18085/stocks/:ticker - the reference data for a specific ticker (or 404 if it does not exist)

 ## S&P 500 companies

The [CSV of S&P 500 companies](./data/s-and-p-500-companies.csv) was populated by copying the data from
[this table from Wikipedia](https://en.wikipedia.org/wiki/List_of_S%26P_500_companies#S&P_500_component_stocks).



## Simple Testing of Reference Data Service`

Obviously this is a lightweight nodeJS service, which you can run, but if you prefer, you can also run a mock of this service by installing `@stoplight/prism-cli`

This statically uses the example content in the OpenAPI spec to mock the service (you can specify `--dynamic` to let it be more creative)

```bash
# Only need to do this once for your machine
sudo npm install -g @stoplight/prism-cli
```

Run prism to mock your OpenAPI spec as follows (Specify `port` as you see fit).
ecurities is random on each request).

```bash
prism --cors --port 18085  mock openapi.yaml
```

You can then try out your requests against the mock service as follows: (or from a browser)

```bash
curl -X GET "http://localhost:18085/stocks" -H "accept: application/json"
curl -X GET "http://localhost:18085/stocks/ADBE" -H "accept: application/json"

```