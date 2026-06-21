#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/dependency-targets.sh"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/order-management-matcher"
TARGET_FRONTEND_DIR="${TARGET_ROOT}/web-front-end/angular"
FRONTEND_OVERRIDE_SOURCE_DIR="${ROOT}/specs/009-order-management-matcher/generation/frontend-overrides/web-front-end/angular"
RUNTIME_OVERRIDES_DIR="${ROOT}/specs/009-order-management-matcher/generation/runtime-overrides"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"
PROMETHEUS_FILE="${STATE_DIR}/observability/prometheus/prometheus.yml"
DASHBOARD_DIR="${STATE_DIR}/observability/grafana/dashboards"
INGRESS_FILE="${TARGET_ROOT}/ingress/nginx.traderx.conf.template"
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

ensure_order_matcher_ingress_route() {
  local ingress_file="$1"
  local tmp_file
  if rg -q "location /order-matcher/" "${ingress_file}"; then
    return 0
  fi

  tmp_file="$(mktemp)"
  awk '
    !added && $0 ~ /^[[:space:]]*location (\/grafana\/|= \/grafana|\/ \{)/ {
      print "    location /order-matcher/ {"
      print "        proxy_pass ${ORDER_MATCHER_URL};"
      print "    }"
      print ""
      added = 1
    }
    { print }
  ' "${ingress_file}" > "${tmp_file}"
  mv "${tmp_file}" "${ingress_file}"
}

install_order_matcher_nats_publisher() {
  local order_matcher_root="${TARGET_ROOT}/order-matcher"
  local gradle_file="${order_matcher_root}/build.gradle"
  local app_props="${order_matcher_root}/src/main/resources/application.properties"
  local test_app_props="${order_matcher_root}/src/test/resources/application.properties"
  local nats_pkg_dir="${order_matcher_root}/src/main/java/finos/traderx/messaging/nats"
  local pubsub_config_file="${order_matcher_root}/src/main/java/finos/traderx/ordermatcher/config/PubSubConfig.java"

  [[ -f "${gradle_file}" ]] || return 0
  [[ -f "${app_props}" ]] || return 0

  if ! rg -q "io.nats:jnats" "${gradle_file}"; then
    perl -0pi -e "s/\n\n  testImplementation/\n  implementation 'io.nats:jnats:2.20.5'\n\n  testImplementation/" "${gradle_file}"
  fi

  mkdir -p "${nats_pkg_dir}"

  cat > "${nats_pkg_dir}/NatsEnvelope.java" <<'EOF'
package finos.traderx.messaging.nats;

import finos.traderx.messaging.Envelope;
import java.util.Date;

public class NatsEnvelope<T> implements Envelope<T> {
  private String topic;
  private T payload;
  private Date date = new Date();
  private String from;
  private String type;

  public NatsEnvelope() {}

  public NatsEnvelope(String topic, T payload, String from) {
    this.payload = payload;
    this.topic = topic;
    this.from = from;
    this.type = (payload == null) ? "Unknown" : payload.getClass().getSimpleName();
  }

  public void setType(String type) {
    this.type = type;
  }

  public void setPayload(T payload) {
    this.payload = payload;
  }

  public void setTopic(String topic) {
    this.topic = topic;
  }

  public void setFrom(String from) {
    this.from = from;
  }

  @Override
  public String getType() {
    return type;
  }

  @Override
  public String getTopic() {
    return topic;
  }

  @Override
  public T getPayload() {
    return payload;
  }

  @Override
  public Date getDate() {
    return date;
  }

  @Override
  public String getFrom() {
    return from;
  }
}
EOF

  cat > "${nats_pkg_dir}/NatsJSONPublisher.java" <<'EOF'
package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public class NatsJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL)
      .registerModule(new JavaTimeModule())
      .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private String serverAddress = "nats://localhost:4222";
  private String topic = "/default";
  private String sender = "publisher";

  public void setServerAddress(String addr) {
    serverAddress = addr;
  }

  public void setTopic(String value) {
    topic = value;
  }

  public void setSender(String value) {
    sender = value;
  }

  @Override
  public boolean isConnected() {
    return connected;
  }

  @Override
  public void publish(T message) throws PubSubException {
    publish(topic, message);
  }

  @Override
  public void publish(String topic, T message) throws PubSubException {
    if (!isConnected()) {
      throw new PubSubException("Cannot send %s on topic %s - not connected".formatted(message, topic));
    }
    try {
      NatsEnvelope<T> envelope = new NatsEnvelope<>(topic, message, sender);
      byte[] payload = OBJECT_MAPPER.writeValueAsBytes(envelope);
      connection.publish(topic, payload);
      connection.flush(Duration.ofSeconds(2));
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    try {
      if (connection != null) {
        connection.close();
      }
      connected = false;
      connection = null;
    } catch (Exception x) {
      throw new PubSubException("Failed to close NATS connection", x);
    }
  }

  @Override
  public void connect() throws PubSubException {
    try {
      Options options = new Options.Builder()
          .server(serverAddress)
          .maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5))
          .build();
      connection = Nats.connect(options);
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
  }
}
EOF

  cat > "${pubsub_config_file}" <<'EOF'
package finos.traderx.ordermatcher.config;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.ordermatcher.api.OrderResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
    @Bean
    @ConditionalOnProperty(name = "order.matcher.publisher", havingValue = "nats", matchIfMissing = true)
    public Publisher<OrderResponse> natsOrderPublisher(
        @Value("${nats.address:nats://${NATS_BROKER_HOST:localhost}:4222}") String natsAddress
    ) {
        NatsJSONPublisher<OrderResponse> publisher = new NatsJSONPublisher<>();
        publisher.setServerAddress(natsAddress);
        publisher.setSender("order-matcher");
        return publisher;
    }

    @Bean
    @ConditionalOnProperty(name = "order.matcher.publisher", havingValue = "noop")
    public Publisher<OrderResponse> noopOrderPublisher() {
        return new Publisher<>() {
            @Override
            public void publish(OrderResponse message) throws PubSubException {}

            @Override
            public void publish(String topic, OrderResponse message) throws PubSubException {}

            @Override
            public boolean isConnected() {
                return true;
            }

            @Override
            public void connect() throws PubSubException {}

            @Override
            public void disconnect() throws PubSubException {}
        };
    }
}
EOF

  if rg -q '^trade.feed.address=' "${app_props}"; then
    perl -0pi -e 's/^trade\.feed\.address=.*$/nats.address=\${NATS_ADDRESS:nats:\/\/\${NATS_BROKER_HOST:localhost}:4222}/m' "${app_props}"
  elif ! rg -q '^nats.address=' "${app_props}"; then
    printf '\nnats.address=${NATS_ADDRESS:nats://${NATS_BROKER_HOST:localhost}:4222}\n' >> "${app_props}"
  fi

  mkdir -p "$(dirname "${test_app_props}")"
  if rg -q '^order.matcher.publisher=' "${test_app_props}" 2>/dev/null; then
    perl -0pi -e 's/^order\.matcher\.publisher=.*$/order.matcher.publisher=noop/m' "${test_app_props}"
  else
    printf 'order.matcher.publisher=noop\n' > "${test_app_props}"
  fi

  if rg -q '^order.matcher.pricing-subscriber.enabled=' "${test_app_props}" 2>/dev/null; then
    perl -0pi -e 's/^order\.matcher\.pricing-subscriber\.enabled=.*$/order.matcher.pricing-subscriber.enabled=false/m' "${test_app_props}"
  else
    printf 'order.matcher.pricing-subscriber.enabled=false\n' >> "${test_app_props}"
  fi
}

require_file "${COMPOSE_FILE}"
require_file "${PROMETHEUS_FILE}"
require_file "${INGRESS_FILE}"
traderx_normalize_yaml_image_tag "${ROOT}" "${COMPOSE_FILE}" "nats"

for service in account-service position-service trade-processor trade-service order-matcher; do
  ensure_gradle_prometheus_support "${TARGET_ROOT}/${service}/build.gradle"
done
install_order_matcher_nats_publisher
if [[ -d "${RUNTIME_OVERRIDES_DIR}" ]]; then
  rsync -a "${RUNTIME_OVERRIDES_DIR}/" "${TARGET_ROOT}/"
fi

perl -0pi -e 's/^name:\s*traderx-state-\d+/name: traderx-state-009/m' "${COMPOSE_FILE}"

bash "${ROOT}/pipeline/normalize-observability-runtime.sh" "009" "${COMPOSE_FILE}"

if ! rg -q "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE" "${COMPOSE_FILE}"; then
  perl -0pi -e 's/(CORS_ALLOWED_ORIGINS: "http:\/\/localhost:8080"\n)/$1      MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,prometheus,info"\n      MANAGEMENT_ENDPOINT_PROMETHEUS_ENABLED: "true"\n      MANAGEMENT_METRICS_EXPORT_PROMETHEUS_ENABLED: "true"\n/g' "${COMPOSE_FILE}"
fi

if ! rg -q "job_name: traderx-spring-boot-actuator" "${PROMETHEUS_FILE}"; then
  perl -0pi -e 's/(  - job_name: blackbox-exporter\n    static_configs:\n      - targets: \["blackbox-exporter:9115"\]\n\n)/$1  - job_name: traderx-spring-boot-actuator\n    metrics_path: \/actuator\/prometheus\n    static_configs:\n      - targets: ["account-service:18088", "position-service:18090", "trade-processor:18091", "trade-service:18092", "order-matcher:18110"]\n\n/s' "${PROMETHEUS_FILE}"
fi

GEN_DEPTH="${TRADERX_GENERATION_DEPTH:-1}"
if [[ "${GEN_DEPTH}" == "1" ]]; then
  ensure_observability_ingress_routes "${INGRESS_FILE}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping ingress observability route mutation"
fi
ensure_order_matcher_ingress_route "${INGRESS_FILE}"

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
- Grafana dashboards (via ingress): `http://localhost:8080/grafana/`
- Grafana (direct): `http://localhost:3001`
- Prometheus: `http://localhost:9090`
- Loki: `http://localhost:3100`
- Tempo: `http://localhost:3200`
- NATS monitor: `http://localhost:8222/varz`
- Price publisher: `http://localhost:18100/health`
- Order matcher: `http://localhost:18110/health`

Grafana access:

- Dashboards are anonymous Viewer surfaces through ingress for demos.
- Local admin access is available at the direct Grafana URL.
- The generated start script prints the active admin credential on startup.
- Defaults are state-scoped: `TRADERX_GRAFANA_ADMIN_USER` falls back to `traderx-admin`; `TRADERX_GRAFANA_ADMIN_PASSWORD` falls back to `traderx-state-009`.
- Override those values before startup for any shared or long-lived environment.
EOF

if [[ -d "${FRONTEND_OVERRIDE_SOURCE_DIR}" ]]; then
  cp -R "${FRONTEND_OVERRIDE_SOURCE_DIR}/." "${TARGET_FRONTEND_DIR}/"
else
  echo "[fail] frontend override source not found: ${FRONTEND_OVERRIDE_SOURCE_DIR}"
  exit 1
fi

echo "[done] rendered state 009 order-management observability refinements into ${STATE_DIR}"
