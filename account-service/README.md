# FINOS | TraderX Sample Trading App | Account Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

A simple application that exposes CRUD functionality over accounts

The API documentation is available via swagger:

`http://localhost:8081/api-docs`

And via UI:

`http://localhost:8081/swagger-ui.html`

It runs on port 8081 which can be changed via the

`server.port=8081` property

How to run the application
Check out the source code from git
`gradlew bootRun`
The app runs on port 8081 and you can access the swagger on `http://localhost:8081/swagger-ui.html`
Configuration can be found in `application.properties` and can be overridden with env vars or command line parameters