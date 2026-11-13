# Order Matcher (Spec-First Generated)

This component is synthesized from the TraderX Spec Kit state overlays and provides persisted limit-order management plus matching.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18110` via `ORDER_MATCHER_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- Price source: `PRICE_SERVICE_URL` (default `http://price-publisher:18100`)
- Trade submit target: `TRADE_SERVICE_URL` (default `http://trade-service:18092/trade/`)
- Matcher tick: `ORDER_MATCHER_TICK_MS` (default `1000`)
- Full-fill threshold: `ORDER_FILL_FULL_THRESHOLD` (default `1000`)
