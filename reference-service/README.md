# reference-service/reference-service

A replacement for a few modules from TraderX - using XTDB as storage to demonstrate [the power of bi-temporality](https://docs.xtdb.com/tutorials/financial-usecase/time-in-finance.html)

## Under covers

The reference-service uses the [CSV with securities](resources/s-and-p-500-companies.csv) to prime a lookup table for stocks. This acts as replacement for the `reference-data` module and is in a separate namespace: [reference-service.data.loader](src/reference_service/data/loader.clj). It could easily be extracted into its own microservice and exposed via web, but as a proof of concept and demonstration it's pragmatic to keep it with reference-service. As a side-effect it seeds XTDB with securities. It also creates accounts used by the application as well as trades and positions used by the `Trade` tab (the original application).

Reference Service has another namespace: [reference-service.price.logic](src/reference_service/price/logic.clj) which does some further seeding of XTDB:

- generates a year's worth of prices for all the securities (seeded by loader), one price per day, with last 15 days having prices generated every two hours. Prices are a random number up to 1000 and thereafter a random value +/- 10% of last stock value.
- generates some trades for the last two weeks for each account. One trade a day for randomly selected security. A trade settles two hours after it's been issued (hence prices are generated every two hours in the last 15 days). The initial trades are `Buy` trades - to open a position (a random quantity of stocks up to 667 at the price of security valid at that point), after which a `Sell` trade is issued a week later (around 30% of which close the position - selling the same quantity as was initially bought, the rest sell 50% + a random amount up to 50%, at the price of security valid at sell time).
- when a trade settles - a position is created or updated (so that quantity and value of security is updated according to Buy/Sell trade)

At runtime prices are generated every two minutes (again - using the same method - last price varied within 10% margin). Prices are stored in XTDB and are sent to the client application via websocket (the client subscribes to 'account prices' - prices of securities this account has traded). The websocket is exposed by trade-feed (which is just a simplification acceptable for purpose of this demo - otherwise the reference-service itself would create a websocket for each client)

The tables are `stocks`, `stock_prices`, `accounts`, `trades`, `positions`, stored in XTDB (which is run as part of [docker compose](../docker-compose.yml#L25))

### Configuration

Application is configured in [application.edn](resources/application.edn). It has sensible defaults for running as part of docker compose.

Use environment variables to override default settings (by either exporting those variables with desired values or passing them with the clojure command, eg: `XTDB_HOST=https://xt-host.com clj -M:run-m`).

Variables used by the application are:

- XTDB_HOST
- XTDB_PORT
- WEB_PORT : what port the application exposes its REST endpoint at
- TRADE_FEED_ADDRESS : trade feed's websocket address
- PRICE_UPDATE_INTERVAL_MS : how ofter are the stock prices updated at runtime - value in milliseconds

If changing any defaults - remember to adjust docker-compose or other services relying on reference-service.

### Running

You'll need [clojure](https://clojure.org/guides/install_clojure).
From the root of reference-service directory run: `clj -M:run-m`
Dependencies will be downloaded into [m2-repo](./m2-repo/)

### Dev environment

Dockerfile is very simple - suitable for development.

### Production environment

If deploying in a more production-like setting - use [Dockerfile.production](Dockerfile.production)
