# Smoke Tests: 012-observability-on-pricing

- Primary smoke script: `scripts/test-state-012-observability-on-pricing.sh`

Implemented smoke checks:

- Runtime starts cleanly with pricing + observability services.
- Grafana/Prometheus/Loki/Tempo/OTel Collector/NATS/price-publisher health endpoints return success.
- Grafana dashboards are provisioned.
- Prometheus blackbox targets include pricing/NATS endpoints.
- Baseline pricing-aware functional flow from state `010` remains green.
