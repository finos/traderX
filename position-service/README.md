# FINOS | TraderX Sample Trading App | Position Service

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

The position service retrieves trades and aggregate positions from the database and returns them to pre-populate a blotter (trades/positions) for a specific accountID specified. Incremental updates are received in the GUI via the pub-sub trade-feed service.