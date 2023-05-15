# FINOS | TraderX Sample Trading App | Account Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)


## Prerequisites and Config

You will need a running instance of the database. This currently is configured to be a H2 Database running on tcp at `$DATABASE_TCP_HOST`:`$DATABASE_TCP_PORT` on the database `$DATABASE_NAME` 

Login details are `$DATABASE_DBUSER` and `$DATABASE_DBPASS`

Default `$ACCOUNT_SERVICE_PORT` is `18088`

In this project, you can run the database by running a shell in the [database](../database/README.md) project and running

```bash
./gradlew build
./run.sh
``` 
## Running The Account Service`

A simple application that exposes CRUD functionality over accounts

The API documentation is available via swagger:

`http://localhost:18088/api-docs`

And via UI:

`http://localhost:18088/swagger-ui.html`

It runs on port 18088 which can be changed via the

`server.port=18088`  system property or `$ACCOUNT_SERVICE_PORT` environment variable.

How to run the application
Check out the source code from git

```bash
gradlew bootRun
```

Configuration can be found in `application.properties` and can be overridden with env vars or command line parameters

``` 
## Simple Testing of Account Service`

You can run a mock of this service by installing `@stoplight/prism-cli`

This statically uses the example content in the OpenAPI spec to mock the service (you can specify `--dynamic` to let it be more creative)

```bash
# Only need to do this once for your machine
sudo npm install -g @stoplight/prism-cli
```

Run prism to mock your OpenAPI spec as follows (Specify `port` as you see fit)
```bash
prism --cors --port 18088 mock openapi.yaml
```

You can then try out your requests against the mock service as follows: (or from a browser)

```bash
curl -X GET "http://localhost:18088/account/" -H "accept: application/json"
curl -X GET "http://localhost:18088/account/22141" -H "accept: application/json"

```