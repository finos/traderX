#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/order-management-matcher"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"
PROMETHEUS_FILE="${STATE_DIR}/observability/prometheus/prometheus.yml"
DASHBOARD_DIR="${STATE_DIR}/observability/grafana/dashboards"
COMPOSE_PROJECT_LABEL="traderx-state-009"

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    echo "[fail] missing required file: ${path}"
    exit 1
  }
}

ensure_gradle_prometheus_support() {
  local gradle_file="$1"
  [[ -f "${gradle_file}" ]] || return 0

  if ! rg -q "spring-boot-starter-actuator" "${gradle_file}"; then
    perl -0pi -e "s/implementation 'org\\.springframework\\.boot:spring-boot-starter-web'\\n/implementation 'org.springframework.boot:spring-boot-starter-web'\\n  implementation 'org.springframework.boot:spring-boot-starter-actuator'\\n  runtimeOnly 'io.micrometer:micrometer-registry-prometheus'\\n/" "${gradle_file}"
  elif ! rg -q "micrometer-registry-prometheus" "${gradle_file}"; then
    perl -0pi -e "s/implementation 'org\\.springframework\\.boot:spring-boot-starter-actuator'\\n/implementation 'org.springframework.boot:spring-boot-starter-actuator'\\n  runtimeOnly 'io.micrometer:micrometer-registry-prometheus'\\n/" "${gradle_file}"
  fi
}

require_file "${COMPOSE_FILE}"
require_file "${PROMETHEUS_FILE}"

for service in account-service position-service trade-processor trade-service order-matcher; do
  ensure_gradle_prometheus_support "${TARGET_ROOT}/${service}/build.gradle"
done

perl -0pi -e 's/^name:\s*traderx-state-\d+/name: traderx-state-009/m' "${COMPOSE_FILE}"

perl -0pi -e 's/"3000:3000"/"${GRAFANA_PORT:-3001}:3000"/g' "${COMPOSE_FILE}"

if ! rg -q "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE" "${COMPOSE_FILE}"; then
  perl -0pi -e 's/(CORS_ALLOWED_ORIGINS: "http:\/\/localhost:8080"\n)/$1      MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,prometheus,info"\n      MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED: "true"\n      MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED: "true"\n/g' "${COMPOSE_FILE}"
fi

if ! rg -q "job_name: traderx-spring-boot-actuator" "${PROMETHEUS_FILE}"; then
  perl -0pi -e 's/(  - job_name: blackbox-exporter\n    static_configs:\n      - targets: \["blackbox-exporter:9115"\]\n\n)/$1  - job_name: traderx-spring-boot-actuator\n    metrics_path: \/actuator\/prometheus\n    static_configs:\n      - targets: ["account-service:18088", "position-service:18090", "trade-processor:18091", "trade-service:18092", "order-matcher:18110"]\n\n/s' "${PROMETHEUS_FILE}"
fi

mkdir -p "${DASHBOARD_DIR}"
cat > "${DASHBOARD_DIR}/traderx-spring-actuator-overview.json" <<'EOF'
{
  "uid": "traderx-spring-actuator-overview",
  "title": "TraderX Spring Actuator Overview",
  "schemaVersion": 39,
  "refresh": "10s",
  "tags": ["traderx", "spring", "prometheus", "provisioned"],
  "time": { "from": "now-30m", "to": "now" },
  "templating": {
    "list": [
      {
        "name": "instance",
        "type": "query",
        "label": "Instance",
        "datasource": { "type": "prometheus", "uid": "prometheus" },
        "query": "label_values(up{job=\"traderx-spring-boot-actuator\"}, instance)",
        "includeAll": true,
        "multi": true,
        "current": { "text": "All", "value": ["$__all"] }
      }
    ]
  },
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "HTTP Request Rate (req/s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
      "targets": [
        { "refId": "A", "expr": "sum by (instance) (rate(http_server_requests_seconds_count{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"}[5m]))" }
      ]
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "HTTP p95 Latency (s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
      "targets": [
        { "refId": "A", "expr": "histogram_quantile(0.95, sum by (instance, le) (rate(http_server_requests_seconds_bucket{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"}[5m])))" }
      ]
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "JVM Heap Used (bytes)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 },
      "targets": [
        { "refId": "A", "expr": "sum by (instance) (jvm_memory_used_bytes{job=\"traderx-spring-boot-actuator\",area=\"heap\",instance=~\"$instance\"})" }
      ]
    },
    {
      "id": 4,
      "type": "stat",
      "title": "Actuator Targets Up",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 8 },
      "targets": [
        { "refId": "A", "expr": "sum(up{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"})" }
      ],
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": null },
              { "color": "green", "value": 1 }
            ]
          }
        }
      }
    }
  ]
}
EOF

cat > "${DASHBOARD_DIR}/traderx-spring-service-sli.json" <<'EOF'
{
  "uid": "traderx-spring-service-sli",
  "title": "TraderX Spring Service SLI",
  "schemaVersion": 39,
  "refresh": "10s",
  "tags": ["traderx", "spring", "sli", "prometheus", "provisioned"],
  "time": { "from": "now-30m", "to": "now" },
  "templating": {
    "list": [
      {
        "name": "instance",
        "type": "query",
        "label": "Instance",
        "datasource": { "type": "prometheus", "uid": "prometheus" },
        "query": "label_values(up{job=\"traderx-spring-boot-actuator\"}, instance)",
        "includeAll": true,
        "multi": true,
        "current": { "text": "All", "value": ["$__all"] }
      }
    ]
  },
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "Scrape Target Availability Ratio",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
      "targets": [
        {
          "refId": "A",
          "expr": "sum(up{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"}) / clamp_min(count(up{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"}), 1)"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "max": 1,
          "unit": "percentunit",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": null },
              { "color": "yellow", "value": 0.9 },
              { "color": "green", "value": 1.0 }
            ]
          }
        }
      }
    },
    {
      "id": 2,
      "type": "timeseries",
      "title": "HTTP 5xx Rate (req/s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 6, "w": 18, "x": 6, "y": 0 },
      "targets": [
        {
          "refId": "A",
          "expr": "sum by (instance) (rate(http_server_requests_seconds_count{job=\"traderx-spring-boot-actuator\",status=~\"5..\",instance=~\"$instance\"}[5m]))"
        }
      ],
      "options": { "legend": { "displayMode": "table", "placement": "bottom" } }
    },
    {
      "id": 3,
      "type": "timeseries",
      "title": "Process CPU Usage (%)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 6 },
      "targets": [
        {
          "refId": "A",
          "expr": "100 * max by (instance) (process_cpu_usage{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"})"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0 } }
    },
    {
      "id": 4,
      "type": "timeseries",
      "title": "GC Pause p95 (s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 6 },
      "targets": [
        {
          "refId": "A",
          "expr": "histogram_quantile(0.95, sum by (instance, le) (rate(jvm_gc_pause_seconds_bucket{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"}[5m])))"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "s" } }
    },
    {
      "id": 5,
      "type": "timeseries",
      "title": "Live Threads",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 14 },
      "targets": [
        {
          "refId": "A",
          "expr": "max by (instance) (jvm_threads_live_threads{job=\"traderx-spring-boot-actuator\",instance=~\"$instance\"})"
        }
      ],
      "options": { "legend": { "displayMode": "table", "placement": "bottom" } }
    }
  ]
}
EOF

cat > "${DASHBOARD_DIR}/traderx-order-matcher-sli.json" <<'EOF'
{
  "uid": "traderx-order-matcher-sli",
  "title": "TraderX Order Matcher SLI",
  "schemaVersion": 39,
  "refresh": "10s",
  "tags": ["traderx", "orders", "matcher", "prometheus", "provisioned"],
  "time": { "from": "now-30m", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "stat",
      "title": "Open Orders",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 5, "w": 6, "x": 0, "y": 0 },
      "targets": [{ "refId": "A", "expr": "max(traderx_orders_open_total)" }]
    },
    {
      "id": 2,
      "type": "stat",
      "title": "Unfilled Orders",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 5, "w": 6, "x": 6, "y": 0 },
      "targets": [{ "refId": "A", "expr": "max(traderx_orders_unfilled_total)" }]
    },
    {
      "id": 3,
      "type": "stat",
      "title": "Order Matcher Actuator Up",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 5, "w": 6, "x": 12, "y": 0 },
      "targets": [{ "refId": "A", "expr": "max(up{job=\"traderx-spring-boot-actuator\",instance=~\".*order-matcher.*\"})" }],
      "fieldConfig": {
        "defaults": {
          "min": 0,
          "max": 1,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": null },
              { "color": "green", "value": 1 }
            ]
          }
        }
      }
    },
    {
      "id": 4,
      "type": "stat",
      "title": "Order Matcher HTTP p95 (s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 5, "w": 6, "x": 18, "y": 0 },
      "targets": [
        {
          "refId": "A",
          "expr": "histogram_quantile(0.95, sum by (le) (rate(http_server_requests_seconds_bucket{job=\"traderx-spring-boot-actuator\",instance=~\".*order-matcher.*\"}[5m])))"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "s" } }
    },
    {
      "id": 5,
      "type": "timeseries",
      "title": "Order Event Rate (5m)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 0, "y": 5 },
      "targets": [
        { "refId": "A", "expr": "sum by (event) (rate(traderx_order_events_total[5m]))" }
      ],
      "options": { "legend": { "displayMode": "table", "placement": "bottom" } }
    },
    {
      "id": 6,
      "type": "timeseries",
      "title": "Matcher Latency p95 (s)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 8, "w": 12, "x": 12, "y": 5 },
      "targets": [
        {
          "refId": "A",
          "expr": "histogram_quantile(0.95, sum by (le) (rate(traderx_order_match_latency_seconds_bucket[5m])))"
        }
      ],
      "fieldConfig": { "defaults": { "unit": "s" } }
    }
  ]
}
EOF

while IFS= read -r dashboard_file; do
  perl -0pi -e "s/compose_project=\\\\\"traderx-state-\\d+\\\\\"/compose_project=\\\\\"${COMPOSE_PROJECT_LABEL}\\\\\"/g" "${dashboard_file}"
done < <(find "${DASHBOARD_DIR}" -maxdepth 1 -type f -name '*.json' | sort)

cat > "${STATE_DIR}/README.md" <<'EOF'
## TraderX State 009 Runtime

This directory defines the compose runtime for:

- `009-order-management-matcher`

It extends pricing + observability runtime with:

- Order matcher service (Spring Boot + DB-backed order persistence)
- Order management APIs (`/order-matcher/orders*`)
- Spring Boot actuator metric scraping (`/actuator/prometheus`) where available
- Provisioned order + Spring dashboards for queue health, lifecycle rates, latency, and JVM/service SLI visibility

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- Grafana: `http://localhost:3001` (local login credentials)
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/health`
- Order matcher: `http://localhost:18110/health`
EOF

echo "[done] rendered state 009 order-management observability refinements into ${STATE_DIR}"
