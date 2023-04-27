# FINOS | TraderX Sample Trading App | Reference Data Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The Reference Data service provides a list of stock tickers and their associated company names via a RESTful interface.

## Prerequisites

This project assumes that your environment is already configured to use node and npm

## Install dependencies (WIP)

```bash
npm install
```

## Running the Reference Data service (WIP)

```bash
npm ci
npm run start
```

By default this will run the application on localhost, port 3000, however the hostname and port can be modified by the following environment variables:

| Environment Variable Name  | Default Value    |
| -------------------------  | ---------------- |
| REFERENCE_DATA_SERVICE_PORT| 3000             |
| HOSTNAME                   | localhost        |

### Running in dev

If you are developing the Reference Data service you can use the **start:dev** script instead. This runs with file
watchers that will automatically rebuild and redeploy the application when the code changes:

```bash
npm run start:dev
```

## Accessing the Reference Data service

Assuming the Reference Data service is running from the default location, otherwise modify the hostname and/or port
accordingly, then the following links are available:
 - http://localhost:3000/api/ - the OpenAPI UI
 - http://localhost:3000/stocks - the reference data
 - http://localhost:3000/stocks/:ticker - the reference data for a specific ticker (or 404 if it does not exist)

 ## S&P 500 companies

The [CSV of S&P 500 companies](./data/s-and-p-500-companies.csv) was populated by copying the data from
[this table from Wikipedia](https://en.wikipedia.org/wiki/List_of_S%26P_500_companies#S&P_500_component_stocks).