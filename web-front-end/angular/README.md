# FINOS | TraderX Sample Trading App | Web Front End (Angular)

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red)
![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The Web Front End provides a UI for users to select an account, view trades and positions, initiate new trades, and to administer the
accounts themselves.

For the trade and position blotters, it will need to query the position service, and subscribe to a given account on the trade feed for
incremental updates.

For executing trades, it will need to query the account service to select an account, the security reference data service to resolve
securities, and the trade service for submitting a trade to be executed.

For managing accounts it will need to connect to the account service to query and update accounts, and to the people service for resolving
users to associate with accounts.

This application was written using Angular, and has hardcoded references to the various services it consumes in `environments` directory in  [environment.ts](environments/environment.ts) and [environment.prod.ts](environments/environment.prod.ts)

### Port Number
This runs an embedded webserver on default port `18093` - which can be changed in the package.json 'start' script, or override using the `WEB_SERVICE_ANGULAR_PORT` environment variable

### Building and Running
To build and run this project:

```bash
npm install
npm run start
```
