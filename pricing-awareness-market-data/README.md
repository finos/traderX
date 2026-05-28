## TraderX State 008 Runtime

This directory defines the compose runtime for:

- `008-pricing-awareness-market-data`

It extends observability runtime with:

- Live market data publishing via `price-publisher`
- Price-aware trade stamping and position cost basis updates
- Trader UI valuation and mark-to-market enhancements

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- Grafana: `http://localhost:3001` (local login credentials)
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/health`
