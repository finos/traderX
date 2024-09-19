# reference-service/reference-service

A replacement for a few modules from TraderX - using XTDB as storage to demonstrate [the power of bi-temporality](https://docs.xtdb.com/tutorials/financial-usecase/time-in-finance.html)

## Under covers

The reference-service uses the [CSV with securities](resources/s-and-p-500-companies.csv) to prime a lookup table for stocks. This acts as replacement for the `reference-data` module and is in a separate namespace: [reference-service.data.loader](src/reference_service/data/loader.clj). It could easily be extracted into its own microservice and exposed via web, but as a proof of concept and demonstration it's pragmatic to keep it with reference-service. As a side-effect it seeds XTDB with securities. It also creates accounts used by the application as well as trades and positions used by the `Trade` tab (the original application).

Reference Service has another namespace: [reference-service.price.logic](src/reference_service/price/logic.clj) which does some further seeding of XTDB:
    - generates a year's worth of prices for all the securities (seeded by loader), one price per day, with last 15 days having prices generated every two hours. Prices are a random number up to 1000 and thereafter a random value +/- 10% of last stock value.
    - generates some trades for the last two weeks for each account. One trade a day for randomly selected security. A trade settles two hours after it's been issued (hence prices are generated every two hours in the last 15 days). The initial trades are `Buy` trades - to open a position (a random quantity of stocks up to 667 at the price of security valid at that point), after which a `Sell` trade is issued a week later (around 30% of which close the position - selling the same quantity as was initially bought, the rest sell 50% + a random amount up to 50%, at the price of security valid at sell time).
    - when a trade settles - a position is created or updated (so that quantity and value of security is updated according to Buy/Sell trade)

At runtime prices are generated every two minutes (again - using the same method - last price varied within 10% margin). Prices are stored in XTDB and are sent to the client application via websocket (the client subscribes to 'account prices' - prices of securities this account has traded).

The tables are `stocks`, `stock_prices`, `accounts`, `trades`, `positions`, stored in XTDB (which is run as part of [docker compose](../docker-compose.yml#25))

### Application Logic Changes

The application has been modified so that it starts with a seed of only `Buy` trades so that we can open stock positions. The naive rationale is that you should not be able to sell securities that you don't have. Therefore if you do not have an open position with given security - you cannot sell it - and if you do have the security - you can only sell as much as you currently have. After all the securities have been sold - a position is closed.

Trades and Positions are additionally saved to XTDB so that we can show a history of changes and consecutive trades. We introduced Prices (as discussed above - randomly generated rather than taken from some Exchange feed - for demonstration running locally they are a good enough approximation of 'live market').

### UI Changes

The existing `Trade` tab had been modified to reflect the logic changes described above:
 - Trades blotter has additional column: Unit Price
 - Positions blotter has two additional columns: Money In/Out, Market Value (how much has been spent/earned in the trades and the current value of the position)
 - Closed Position blotter has been added showing security, P&L (profit and loss) and current Unit Price
 - Create Trade Ticket modal displays error message when application logic is violated so that it's evident why a trade is not created when you hit 'Create' button. It shows current unit price of selected stock and will also disallow Selling a security for which you don't have an open position (or more units than you have).

A new `Report` tab has been added - which allows you inspecting history of your trades and positions as well as show what the market value of a position would have been at a given point in time.
There are two sliders - one at the top allows you to see what trades (and subsequently positions) were created. The slider at the bottom allows you to 'navigate through' past security prices (showing what the market value of a position would be at the prices at some point in the past)
Positions and Closed Positions blotters have `Calculation` column showing how the current value has been calculated (this example is very simplistic - but would have much more value if there were some more inputs for the calculation)

### Dev environment

Dockerfile is very simple - suitable for development.

### Production environment

If deploying in a more production-like setting - use [Dockerfile.production](Dockerfile.production)
