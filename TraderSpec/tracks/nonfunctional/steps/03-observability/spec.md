# Spec: NF 03 Observability

- `stepId`: `nf-03-observability`
- `inheritsFrom`: `nf-02-oauth2|nf-02-zero-trust`
- `requirementMode`: `nfr-overlay-only`

## NFR Additions

- Unified metrics, logs, and traces.
- Golden signal visibility (latency, errors, throughput).
- Operational dashboards and alert seeds.

## Acceptance

- Core services emit telemetry with consistent correlation IDs.
- Golden signals are queryable for critical workflows.
