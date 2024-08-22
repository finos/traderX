# reference-service/reference-service

A replacement for a few modules from TraderX - using XTDB as storage to demonstrate [the power of bi-temporality](https://docs.xtdb.com/tutorials/financial-usecase/time-in-finance.html)

## Under covers

The reference-service uses the [CSV with securities](resources/s-and-p-500-companies.csv) to prime a lookup table for stocks. It also assigns initial (pseudo-randomly generated) 'stock prices'.

The tables are `stocks` and `stock_prices` respectively, stored in XTDB (which is run as part of [docker compose](../docker-compose.yml#25))

### Dev environment

Dockerfile is very simple - suitable for development.

### Production environment

If deploying in a more production-like setting - use [Dockerfile.production](Dockerfile.production)
