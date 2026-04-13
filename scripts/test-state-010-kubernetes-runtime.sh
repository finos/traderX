#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi

INGRESS_URL="${1:-http://localhost:8080}"
NAMESPACE="${2:-traderx}"
K8S_PROVIDER="${3:-${K8S_PROVIDER:-kind}}"
BUILD_PLAN="${GENERATED_ROOT}/code/target-generated/kubernetes-runtime/build-plan.json"
DEFAULT_CLUSTER_NAME="traderx-state-010"

if [[ -f "${BUILD_PLAN}" ]] && command -v jq >/dev/null 2>&1; then
  parsed_cluster_name="$(jq -r '.kindClusterName // empty' "${BUILD_PLAN}" 2>/dev/null || true)"
  if [[ -n "${parsed_cluster_name}" && "${parsed_cluster_name}" != "null" ]]; then
    DEFAULT_CLUSTER_NAME="${parsed_cluster_name}"
  fi
fi

MINIKUBE_PROFILE="${4:-${MINIKUBE_PROFILE:-${DEFAULT_CLUSTER_NAME}}}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[error] kubectl command not found"
  exit 1
fi

case "${K8S_PROVIDER}" in
  kind)
    if ! command -v kind >/dev/null 2>&1; then
      echo "[error] kind command not found"
      exit 1
    fi
    if ! kind get clusters | grep -Fx "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[error] expected kind cluster not found: ${MINIKUBE_PROFILE}"
      exit 1
    fi
    kubectl config use-context "kind-${MINIKUBE_PROFILE}" >/dev/null
    ;;
  minikube)
    if ! command -v minikube >/dev/null 2>&1; then
      echo "[error] minikube command not found"
      exit 1
    fi
    if ! minikube status -p "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      echo "[error] expected minikube profile not running: ${MINIKUBE_PROFILE}"
      exit 1
    fi
    if ! kubectl config use-context "${MINIKUBE_PROFILE}" >/dev/null 2>&1; then
      kubectl config use-context "minikube" >/dev/null
    fi
    ;;
  *)
    echo "[error] unsupported provider: ${K8S_PROVIDER}"
    echo "[hint] supported providers: kind, minikube"
    exit 1
    ;;
esac

echo "[check] kubernetes deployments available in namespace ${NAMESPACE}"
kubectl get deployments -n "${NAMESPACE}"
kubectl wait --for=condition=Available deployment --all -n "${NAMESPACE}" --timeout=180s >/dev/null

echo "[check] edge health endpoint"
health_headers="$(curl -sS -i "${INGRESS_URL}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/health"
  exit 1
}

echo "[check] edge account-service path"
account_headers="$(curl -sS -i "${INGRESS_URL}/account-service/account/22214" | sed -n '1,25p')"
echo "${account_headers}"
printf '%s\n' "${account_headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/account-service/account/22214"
  exit 1
}

echo "[check] order matcher ingress health and listing endpoints"
order_health_headers="$(curl -sS -i "${INGRESS_URL}/order-matcher/health" | sed -n '1,25p')"
echo "${order_health_headers}"
printf '%s\n' "${order_health_headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/order-matcher/health"
  exit 1
}

order_listing_payload="$(curl -sS -w '\n%{http_code}' "${INGRESS_URL}/order-matcher/orders?status=open")"
order_listing_http="$(echo "${order_listing_payload}" | tail -n1)"
order_listing_body="$(echo "${order_listing_payload}" | sed '$d')"
if [[ "${order_listing_http}" != "200" ]]; then
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/order-matcher/orders?status=open, got ${order_listing_http}"
  echo "${order_listing_body}"
  exit 1
fi
echo "${order_listing_body}" | jq -e 'if type=="array" then . else empty end' >/dev/null || {
  echo "[error] expected order-matcher list response to be a JSON array"
  echo "${order_listing_body}"
  exit 1
}

echo "[check] observability ingress routes"
grafana_headers="$(curl -sS -i "${INGRESS_URL}/grafana/api/health" | sed -n '1,25p')"
echo "${grafana_headers}"
printf '%s\n' "${grafana_headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/grafana/api/health"
  exit 1
}

prometheus_headers="$(curl -sS -i "${INGRESS_URL}/prometheus/-/ready" | sed -n '1,25p')"
echo "${prometheus_headers}"
printf '%s\n' "${prometheus_headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
  echo "[error] expected HTTP 200 from ${INGRESS_URL}/prometheus/-/ready"
  exit 1
}

echo "[check] prometheus query API responds"
prometheus_query_payload="$(curl -sS "${INGRESS_URL}/prometheus/api/v1/query?query=up" | tr -d '\n')"
printf '%s\n' "${prometheus_query_payload}" | grep -q '"status":"success"' || {
  echo "[error] expected Prometheus API query to return status=success"
  exit 1
}

echo "[check] grafana datasource can query prometheus"
now_ms=$(($(date +%s) * 1000))
from_ms=$((now_ms - 10 * 60 * 1000))
grafana_query_result="$(
  curl -sS -u admin:admin -H 'Content-Type: application/json' -X POST "${INGRESS_URL}/grafana/api/ds/query" \
    -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"prometheus\",\"type\":\"prometheus\"},\"expr\":\"probe_success{job=\\\"traderx-http-probe\\\"}\",\"instant\":true,\"range\":false,\"intervalMs\":1000,\"maxDataPoints\":500}]}"
)"
grafana_query_error="$(echo "${grafana_query_result}" | jq -r '.results.A.error // empty')"
grafana_query_frames="$(echo "${grafana_query_result}" | jq -r '.results.A.frames | length')"
if [[ -n "${grafana_query_error}" ]]; then
  echo "[error] grafana datasource query failed: ${grafana_query_error}"
  exit 1
fi
if [[ "${grafana_query_frames}" -lt 1 ]]; then
  echo "[error] expected at least one Grafana data frame from Prometheus query"
  exit 1
fi

echo "[check] spring actuator scrape targets healthy in prometheus"
actuator_up_count=0
for _ in {1..30}; do
  actuator_up_count="$(
    curl -sS "${INGRESS_URL}/prometheus/api/v1/targets" \
    | jq '[.data.activeTargets[] | select(.labels.job=="traderx-spring-boot-actuator" and .health=="up")] | length'
  )"
  if [[ "${actuator_up_count}" -ge 5 ]]; then
    break
  fi
  sleep 2
done
if [[ "${actuator_up_count}" -lt 5 ]]; then
  echo "[error] expected 5 healthy Spring actuator scrape targets, got ${actuator_up_count}"
  curl -sS "${INGRESS_URL}/prometheus/api/v1/targets" \
    | jq -r '.data.activeTargets[] | select(.labels.job=="traderx-spring-boot-actuator") | "\(.labels.instance) health=\(.health) error=\(.lastError // "")"'
  exit 1
fi

echo "[check] spring actuator endpoints reachable through ingress"
for endpoint in \
  "${INGRESS_URL}/account-service/actuator/prometheus" \
  "${INGRESS_URL}/position-service/actuator/prometheus" \
  "${INGRESS_URL}/trade-processor/actuator/prometheus" \
  "${INGRESS_URL}/trade-service/actuator/prometheus" \
  "${INGRESS_URL}/order-matcher/actuator/prometheus"; do
  headers="$(curl -sS -i "${endpoint}" | sed -n '1,20p')"
  echo "${headers}"
  printf '%s\n' "${headers}" | grep -Eq "HTTP/1\\.[01] 200" || {
    echo "[error] expected HTTP 200 from ${endpoint}"
    exit 1
  }
done

echo "[check] warm traffic for spring http_server metrics"
curl -sS "${INGRESS_URL}/account-service/account/22214" >/dev/null
curl -sS "${INGRESS_URL}/position-service/positions/22214" >/dev/null
curl -sS "${INGRESS_URL}/trade-service/swagger-ui.html" >/dev/null
curl -sS "${INGRESS_URL}/trade-processor/health" >/dev/null
curl -sS "${INGRESS_URL}/order-matcher/orders/open-count" >/dev/null

echo "[check] spring http_server metrics are queryable in prometheus"
spring_metric_sample_count="$(
  curl -sS --get "${INGRESS_URL}/prometheus/api/v1/query" \
    --data-urlencode 'query=count(http_server_requests_seconds_count{job="traderx-spring-boot-actuator"})' \
  | jq -r '.data.result[0].value[1] // "0"'
)"
if ! awk "BEGIN {exit !(${spring_metric_sample_count} > 0)}"; then
  echo "[error] expected spring http_server metric samples, got ${spring_metric_sample_count}"
  exit 1
fi

echo "[check] promtail daemonset is available"
kubectl rollout status daemonset/promtail -n "${NAMESPACE}" --timeout=180s >/dev/null

echo "[check] grafana loki datasource has ingesting log streams"
now_ms=$(($(date +%s) * 1000))
from_ms=$((now_ms - 15 * 60 * 1000))
loki_total_query_result="$(
  curl -sS -u admin:admin -H 'Content-Type: application/json' -X POST "${INGRESS_URL}/grafana/api/ds/query" \
    -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"loki\",\"type\":\"loki\"},\"expr\":\"sum(count_over_time({compose_project=\\\"traderx-state-009\\\"}[5m]))\",\"queryType\":\"range\",\"intervalMs\":1000,\"maxDataPoints\":500}]}"
)"
loki_total_query_error="$(echo "${loki_total_query_result}" | jq -r '.results.A.error // empty')"
loki_total_last="$(echo "${loki_total_query_result}" | jq -r '.results.A.frames[0].data.values[1][-1] // "0"')"
if [[ -n "${loki_total_query_error}" ]]; then
  echo "[error] grafana loki query failed: ${loki_total_query_error}"
  exit 1
fi
if ! awk "BEGIN {exit !(${loki_total_last} > 0)}"; then
  echo "[error] expected non-empty Loki ingestion in last 5m, got ${loki_total_last}"
  exit 1
fi

echo "[check] dashboard service filters have log content (nats/pipeline/control-plane)"
loki_service_query_result="$(
  curl -sS -u admin:admin -H 'Content-Type: application/json' -X POST "${INGRESS_URL}/grafana/api/ds/query" \
    -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"loki\",\"type\":\"loki\"},\"expr\":\"sum(count_over_time({compose_project=\\\"traderx-state-009\\\",service=~\\\"nats-broker|trade-service|trade-processor|price-publisher|position-service|grafana|loki|tempo|otel-collector|prometheus|edge-proxy\\\"}[10m]))\",\"queryType\":\"range\",\"intervalMs\":1000,\"maxDataPoints\":500}]}"
)"
loki_service_query_error="$(echo "${loki_service_query_result}" | jq -r '.results.A.error // empty')"
loki_service_last="$(echo "${loki_service_query_result}" | jq -r '.results.A.frames[0].data.values[1][-1] // "0"')"
if [[ -n "${loki_service_query_error}" ]]; then
  echo "[error] grafana loki service-filter query failed: ${loki_service_query_error}"
  exit 1
fi
if ! awk "BEGIN {exit !(${loki_service_last} > 0)}"; then
  echo "[error] expected non-empty service-filtered Loki logs for dashboard panels, got ${loki_service_last}"
  exit 1
fi

echo "[check] state 010 ingress-routed service smoke suite"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/reference-data"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/account-service"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/people-service" "${INGRESS_URL}/account-service/accountuser/"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/position-service"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${INGRESS_URL}" "${INGRESS_URL}/trade-service" "${INGRESS_URL}/position-service"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 010 kubernetes runtime smoke tests passed"
