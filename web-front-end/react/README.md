# Getting Started with Create React App

This project was bootstrapped with [Create React App](https://github.com/facebook/create-react-app).

## Available Scripts

In the project directory, you can run:

### `npm start`

For managing accounts it will need to connect to the account service to query and update accounts, and to the people service for resolving users to associate with accounts.

## API Gateway / Service Proxy

in the `proxy` directory, you can run a proxy to aggregate all of the services. This may simplify the gui development and represent an API Gateway.

To run the proxy 
```bash
cd proxy
npm install 
npm run start
```

This is a development proxy, and you can change [proxy/routes.js](routes.js) to add new routes and it will re-load upon save.

The only thing which the GUI needs to connect to which cannot be proxied is the trade-feed which makes use of websockets.

When using this proxy, the gui only needs to make HTTP requests to this proxy, and to connect to the trade feed.

This proxy honors all `*_SERVICE_PORT` variables which can be set in the environment when running other services. For details on default ports, please see the main README for this project.

Note: When using SwaggerUI / API Docs - things may redirect and may not work. This is a limitation of this approach, without a more sophisticated proxy.  The URLs you need to send requests to, however, all work.

Here are sample URLs when using the proxy, that the GUI will need to hit:

```
/trade/trade -> Submit a HTTP  POST request to the trading service

/people/People/GetMatchingPeople?SearchText=user01 -> Searches people service

/refdata/stocks -> Gets static list of reference data securities for drop-down

/positions/trades/22214 -> Loads all trade  data for account 22214 (for trade blotter hydration)
/positions/positions/22214 -> Loads all position  data for account 22214 (for position blotter hydration)

/accounts/account/ -> Lists all accounts in the system (needed for the account dropdown)
```
