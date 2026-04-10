# Smoke Tests: 008-pricing-awareness-market-data

- Primary smoke script: `scripts/test-state-008-pricing-awareness-market-data.sh`

Implemented smoke checks:

- Runtime starts cleanly with pricing + observability services.
- Grafana/Prometheus/Loki/Tempo/OTel Collector/NATS/price-publisher health endpoints return success.
- Grafana dashboards are provisioned.
- Prometheus blackbox targets include pricing/NATS endpoints.
- Baseline pricing-aware functional flow from state `010` remains green.
