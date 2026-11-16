# Runtime Topology

Inherited C2 Compose runtime plus exposure-service:18120; state 018 adds internal FalkorDB:6379 with a persistent volume. NGINX /exposure/ proxies the sidecar. PostgreSQL remains authoritative. Prometheus scrapes /metrics. No external FalkorDB port is published.
