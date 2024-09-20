# FINOS | TraderX Sample Trading App | Web Front End

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The Web Front End provides a UI for users to select an account, view trades and positions, initiate new trades, and to administer the accounts themselves.

For the trade  and position blotters, it will need to query the position service, and subscribe to a given account on the trade feed for incremental updates.

For executing trades, it will need to query the account service to select an account, the security reference data service to resolve securities, and the trade service for submitting a trade to be executed.

For managing accounts it will need to connect to the account service to query and update accounts, and to the people service for resolving users to associate with accounts.

## UI Changes

The existing `Trade` tab had been modified to reflect the logic changes described above:

- Trades blotter has additional column: Unit Price
- Positions blotter has two additional columns: Money In/Out, Market Value (how much has been spent/earned in the trades and the current value of the position)
- Closed Position blotter has been added showing security, P&L (profit and loss) and current Unit Price
- Create Trade Ticket modal displays error message when application logic is violated so that it's evident why a trade is not created when you hit 'Create' button. It shows current unit price of selected stock and will also disallow Selling a security for which you don't have an open position (or more units than you have).

A new `Report` tab has been added - which allows you inspecting history of your trades and positions as well as show what the market value of a position would have been at a given point in time.

There are two sliders - one at the top allows you to see what trades (and subsequently positions) were created. The slider at the bottom allows you to 'navigate through' past security prices (showing what the market value of a position would be at the prices at some point in the past)

Positions and Closed Positions blotters have `Calculation` column showing how the current value has been calculated (this example is very simplistic - but would have much more value if there were some more inputs for the calculation)
