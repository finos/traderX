#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/observability-lgtm-compose"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"
PROMETHEUS_FILE="${STATE_DIR}/observability/prometheus/prometheus.yml"
DASHBOARD_DIR="${STATE_DIR}/observability/grafana/dashboards"
INGRESS_FILE="${TARGET_ROOT}/ingress/nginx.traderx.conf.template"
COMPOSE_PROJECT_LABEL="traderx-state-007"

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

ensure_observability_ingress_routes() {
  local ingress_file="$1"
  local tmp_file
  if rg -q "location /grafana/" "${ingress_file}" && rg -q "location /prometheus/" "${ingress_file}"; then
    return 0
  fi

  tmp_file="$(mktemp)"
  awk '
    !added && $0 ~ /^[[:space:]]*location \/ \{/ {
      print "    location = /grafana {"
      print "        return 301 /grafana/;"
      print "    }"
      print ""
      print "    location /grafana/ {"
      print "        proxy_pass http://grafana:3000;"
      print "        proxy_http_version 1.1;"
      print "        proxy_set_header Host $host;"
      print "        proxy_set_header X-Forwarded-Host $host;"
      print "        proxy_set_header X-Forwarded-Server $host;"
      print "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
      print "        proxy_set_header X-Forwarded-Proto $scheme;"
      print "        proxy_set_header X-Forwarded-Prefix /grafana;"
      print "        proxy_set_header Upgrade $http_upgrade;"
      print "        proxy_set_header Connection \"upgrade\";"
      print "    }"
      print ""
      print "    location = /prometheus {"
      print "        return 301 /prometheus/;"
      print "    }"
      print ""
      print "    location /prometheus/ {"
      print "        proxy_pass http://prometheus:9090;"
      print "        proxy_http_version 1.1;"
      print "        proxy_set_header Host $host;"
      print "        proxy_set_header X-Forwarded-Host $host;"
      print "        proxy_set_header X-Forwarded-Server $host;"
      print "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;"
      print "        proxy_set_header X-Forwarded-Proto $scheme;"
      print "        proxy_set_header X-Forwarded-Prefix /prometheus;"
      print "    }"
      print ""
      added = 1
    }
    { print }
  ' "${ingress_file}" > "${tmp_file}"
  mv "${tmp_file}" "${ingress_file}"
}

require_file "${COMPOSE_FILE}"
require_file "${PROMETHEUS_FILE}"
require_file "${INGRESS_FILE}"

for service in account-service position-service trade-processor trade-service; do
  ensure_gradle_prometheus_support "${TARGET_ROOT}/${service}/build.gradle"
done

# Keep generated compose metadata aligned with this state id for manual `docker compose` flows.
perl -0pi -e 's/^name:\s*traderx-state-\d+/name: traderx-state-007/m' "${COMPOSE_FILE}"

bash "${ROOT}/pipeline/normalize-observability-runtime.sh" "007" "${COMPOSE_FILE}"

if ! rg -q "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE" "${COMPOSE_FILE}"; then
  perl -0pi -e 's/(CORS_ALLOWED_ORIGINS: "http:\/\/localhost:8080"\n)/$1      MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,prometheus,info"\n      MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED: "true"\n      MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED: "true"\n/g' "${COMPOSE_FILE}"
fi

if ! rg -q "job_name: traderx-spring-boot-actuator" "${PROMETHEUS_FILE}"; then
  perl -0pi -e 's/(  - job_name: blackbox-exporter\n    static_configs:\n      - targets: \["blackbox-exporter:9115"\]\n\n)/$1  - job_name: traderx-spring-boot-actuator\n    metrics_path: \/actuator\/prometheus\n    static_configs:\n      - targets: ["account-service:18088", "position-service:18090", "trade-processor:18091", "trade-service:18092"]\n\n/s' "${PROMETHEUS_FILE}"
fi

GEN_DEPTH="${TRADERX_GENERATION_DEPTH:-1}"
if [[ "${GEN_DEPTH}" == "1" ]]; then
  ensure_observability_ingress_routes "${INGRESS_FILE}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping ingress observability route mutation"
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

cat > "${DASHBOARD_DIR}/traderx-message-bus-connectivity.json" <<'EOF'
{
  "uid": "traderx-message-bus-connectivity",
  "title": "TraderX Message Bus Connectivity",
  "schemaVersion": 39,
  "refresh": "10s",
  "tags": ["traderx", "messaging", "health", "prometheus", "provisioned"],
  "time": { "from": "now-30m", "to": "now" },
  "panels": [
    {
      "id": 1,
      "type": "timeseries",
      "title": "Message Bus Connectivity (1=Connected)",
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "gridPos": { "h": 10, "w": 24, "x": 0, "y": 0 },
      "targets": [
        {
          "refId": "A",
          "expr": "traderx_messagebus_connected",
          "legendFormat": "{{component}}/{{role}}"
        }
      ],
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
      },
      "options": {
        "legend": {
          "displayMode": "table",
          "placement": "bottom",
          "showLegend": true
        }
      }
    }
  ]
}
EOF

# Normalize legacy compose labels embedded in dashboard queries so Loki panels resolve for state 007.
while IFS= read -r dashboard_file; do
  perl -0pi -e "s/compose_project=\\\\\"traderx-state-\\d+\\\\\"/compose_project=\\\\\"${COMPOSE_PROJECT_LABEL}\\\\\"/g" "${dashboard_file}"
done < <(find "${DASHBOARD_DIR}" -maxdepth 1 -type f -name '*.json' | sort)

cat > "${STATE_DIR}/README.md" <<'EOF'
## TraderX State 007 Runtime

This directory defines the compose runtime for:

- `007-observability-lgtm-compose`

It extends the containerized stack with:

- OpenTelemetry Collector
- Prometheus
- Loki
- Grafana
- Tempo
- Promtail
- Blackbox Exporter
- Spring Boot actuator metric scraping (`/actuator/prometheus`) where available
- Provisioned Spring dashboards for request/latency, JVM health, and SLI trend visibility

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- Grafana (via ingress): `http://localhost:8080/grafana` (admin/admin)
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- OTel Collector health: `http://localhost:13133`
EOF

echo "[done] rendered state 007 observability refinements into ${STATE_DIR}"
