#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORDER_MATCHER_PORT="${ORDER_MATCHER_PORT:-18110}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-013}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/order-management-matcher/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 013-order-management-matcher"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 19 ]]; then
  echo "[error] expected 19+ running services, got ${running_services}"
  exit 1
fi

echo "[check] observability control-plane endpoints"
for endpoint in \
  "http://localhost:3000/api/health" \
  "http://localhost:9090/-/ready" \
  "http://localhost:3100/ready" \
  "http://localhost:3200/ready"; do
  headers="$(curl -sS -i "${endpoint}" | sed -n '1,20p')"
  echo "${headers}"
  printf '%s\n' "${headers}" | grep -q "200" || {
    echo "[error] expected 200 from ${endpoint}"
    exit 1
  }
done

echo "[check] order matcher health and metrics endpoints"
health_headers="$(curl -sS -i "http://localhost:${ORDER_MATCHER_PORT}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "200" || {
  echo "[error] expected 200 from order matcher health endpoint"
  exit 1
}

metrics_body="$(curl -fsS "http://localhost:${ORDER_MATCHER_PORT}/metrics")"
printf '%s\n' "${metrics_body}" | rg -q '^traderx_orders_open_total' || {
  echo "[error] missing metric traderx_orders_open_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_orders_unfilled_total' || {
  echo "[error] missing metric traderx_orders_unfilled_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_order_events_total' || {
  echo "[error] missing metric traderx_order_events_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_order_match_latency_seconds_bucket' || {
  echo "[error] missing metric traderx_order_match_latency_seconds histogram"
  exit 1
}
echo "[info] required order metrics detected"

echo "[check] grafana order dashboards provisioned"
dashboard_uids_raw="$(
  curl -sS -u admin:admin "http://localhost:3000/api/search?query=TraderX&type=dash-db" \
  | jq -r '.[].uid'
)"
if [[ -z "${dashboard_uids_raw}" ]]; then
  echo "[error] expected at least one provisioned TraderX dashboard in Grafana (type=dash-db)"
  exit 1
fi
order_metrics_dashboard_uid=""
while IFS= read -r dashboard_uid; do
  [[ -z "${dashboard_uid}" ]] && continue
  dashboard_payload="$(curl -sS -u admin:admin "http://localhost:3000/api/dashboards/uid/${dashboard_uid}")"
  dashboard_text="$(echo "${dashboard_payload}" | jq -r '.dashboard | tostring')"
  if printf '%s\n' "${dashboard_text}" | rg -q 'traderx_orders_open_total|traderx_order_events_total'; then
    order_metrics_dashboard_uid="${dashboard_uid}"
    break
  fi
done <<< "${dashboard_uids_raw}"
if [[ -z "${order_metrics_dashboard_uid}" ]]; then
  echo "[error] no provisioned TraderX dashboard includes order observability metric queries"
  exit 1
fi
echo "[info] grafana dashboard uid=${order_metrics_dashboard_uid} includes order observability metrics"

echo "[check] prometheus discovered order-matcher scrape target"
target_count="$(
  curl -sS "http://localhost:9090/api/v1/targets" \
  | jq '[.data.activeTargets[] | select(((.labels.instance // "") | test("order-matcher")) or ((.discoveredLabels.__address__ // "") | test("order-matcher")))] | length'
)"
if [[ "${target_count}" -lt 1 ]]; then
  echo "[error] expected at least one active order-matcher target in Prometheus"
  exit 1
fi
echo "[info] prometheus order-matcher targets=${target_count}"

echo "[check] ingress remains healthy"
curl -fsS "${INGRESS_URL}/health" >/dev/null

echo "[check] order admin API through ingress"
orders_payload="$(curl -fsS "${INGRESS_URL}/order-matcher/orders?status=open")"
echo "${orders_payload}" | jq '.[0]' >/dev/null
orders_count="$(echo "${orders_payload}" | jq 'length')"
if [[ "${orders_count}" -lt 1 ]]; then
  echo "[error] expected at least one open order from ingress order-matcher API"
  exit 1
fi
echo "[info] open orders via ingress=${orders_count}"

echo "[check] user journey: create order from ticket flow"
pre_open_count="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/open-count" | jq -r '.openOrders')"
create_payload='{"accountId":22214,"security":"IBM","side":"Buy","quantity":77,"limitPrice":188.125}'
create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
create_http="$(echo "${create_response}" | tail -n1)"
create_body="$(echo "${create_response}" | sed '$d')"
if [[ "${create_http}" != "201" ]]; then
  echo "[error] expected 201 from create order, got ${create_http}"
  echo "${create_body}"
  exit 1
fi
created_order_id="$(echo "${create_body}" | jq -r '.orderId // empty')"
if [[ -z "${created_order_id}" ]]; then
  echo "[error] create order response missing orderId"
  echo "${create_body}"
  exit 1
fi
echo "[info] created order=${created_order_id}"

echo "[check] user journey: account-scoped open orders listing includes created order"
account_open_orders="$(curl -fsS "${INGRESS_URL}/order-matcher/orders?status=open&accountId=22214")"
listed_count="$(echo "${account_open_orders}" | jq --arg order_id "${created_order_id}" '[.[] | select(.orderId == $order_id)] | length')"
if [[ "${listed_count}" -lt 1 ]]; then
  echo "[error] expected created order ${created_order_id} in account open-orders listing"
  exit 1
fi

echo "[check] user journey: cancel open order"
cancel_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{}' \
    "${INGRESS_URL}/order-matcher/orders/${created_order_id}/cancel"
)"
cancel_http="$(echo "${cancel_response}" | tail -n1)"
cancel_body="$(echo "${cancel_response}" | sed '$d')"
if [[ "${cancel_http}" != "200" ]]; then
  echo "[error] expected 200 from cancel order, got ${cancel_http}"
  echo "${cancel_body}"
  exit 1
fi
cancel_status="$(echo "${cancel_body}" | jq -r '.status // empty')"
if [[ "${cancel_status}" != "CANCELED" ]]; then
  echo "[error] expected canceled order status, got ${cancel_status}"
  echo "${cancel_body}"
  exit 1
fi

echo "[check] admin journey: force-fill an open order"
pre_trade_count="$(curl -fsS "${INGRESS_URL}/position-service/trades/44044" | jq 'length')"
pre_jpm_position_qty="$(curl -fsS "${INGRESS_URL}/position-service/positions/44044" | jq -r '[.[] | select(.security == "JPM")][0].quantity // 0')"
admin_create_payload='{"accountId":44044,"security":"JPM","side":"Sell","quantity":55,"limitPrice":191.875}'
admin_create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${admin_create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
admin_create_http="$(echo "${admin_create_response}" | tail -n1)"
admin_create_body="$(echo "${admin_create_response}" | sed '$d')"
if [[ "${admin_create_http}" != "201" ]]; then
  echo "[error] expected 201 from admin setup create order, got ${admin_create_http}"
  echo "${admin_create_body}"
  exit 1
fi
admin_order_id="$(echo "${admin_create_body}" | jq -r '.orderId // empty')"
if [[ -z "${admin_order_id}" ]]; then
  echo "[error] admin setup create order missing orderId"
  echo "${admin_create_body}"
  exit 1
fi
force_fill_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{}' \
    "${INGRESS_URL}/order-matcher/orders/${admin_order_id}/force-fill"
)"
force_fill_http="$(echo "${force_fill_response}" | tail -n1)"
force_fill_body="$(echo "${force_fill_response}" | sed '$d')"
if [[ "${force_fill_http}" != "200" ]]; then
  echo "[error] expected 200 from force-fill order, got ${force_fill_http}"
  echo "${force_fill_body}"
  exit 1
fi
force_fill_status="$(echo "${force_fill_body}" | jq -r '.status // empty')"
if [[ "${force_fill_status}" != "FILLED" ]]; then
  echo "[error] expected force-filled order status FILLED, got ${force_fill_status}"
  echo "${force_fill_body}"
  exit 1
fi
echo "[check] force-filled order created trade and changed position"
trade_observed=0
for _ in {1..30}; do
  trades_after="$(curl -fsS "${INGRESS_URL}/position-service/trades/44044")"
  trade_count_after="$(echo "${trades_after}" | jq 'length')"
  matched_trade_count="$(echo "${trades_after}" | jq '[.[] | select(.security == "JPM" and .side == "Sell" and .quantity == 55)] | length')"
  if [[ "${trade_count_after}" -gt "${pre_trade_count}" && "${matched_trade_count}" -ge 1 ]]; then
    trade_observed=1
    break
  fi
  sleep 2
done
if [[ "${trade_observed}" -ne 1 ]]; then
  echo "[error] expected force-fill to produce persisted JPM sell trade for account 44044"
  exit 1
fi
expected_jpm_position_qty="$((pre_jpm_position_qty - 55))"
position_observed=0
for _ in {1..30}; do
  position_rows="$(curl -fsS "${INGRESS_URL}/position-service/positions/44044")"
  current_jpm_qty="$(echo "${position_rows}" | jq -r '[.[] | select(.security == "JPM")][0].quantity // 0')"
  if [[ "${current_jpm_qty}" == "${expected_jpm_position_qty}" ]]; then
    position_observed=1
    break
  fi
  sleep 2
done
if [[ "${position_observed}" -ne 1 ]]; then
  echo "[error] expected JPM position quantity=${expected_jpm_position_qty} after force-fill"
  exit 1
fi

echo "[check] matcher journey: in-the-money order auto-fills on tick policy"
autofill_create_payload='{"accountId":22214,"security":"IBM","side":"Buy","quantity":5000,"limitPrice":99999.000}'
autofill_create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${autofill_create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
autofill_create_http="$(echo "${autofill_create_response}" | tail -n1)"
autofill_create_body="$(echo "${autofill_create_response}" | sed '$d')"
if [[ "${autofill_create_http}" != "201" ]]; then
  echo "[error] expected 201 from auto-fill setup create order, got ${autofill_create_http}"
  echo "${autofill_create_body}"
  exit 1
fi
autofill_order_id="$(echo "${autofill_create_body}" | jq -r '.orderId // empty')"
if [[ -z "${autofill_order_id}" ]]; then
  echo "[error] auto-fill setup create order missing orderId"
  echo "${autofill_create_body}"
  exit 1
fi
autofill_first_remaining=""
for _ in {1..20}; do
  autofill_order="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/${autofill_order_id}")"
  autofill_status="$(echo "${autofill_order}" | jq -r '.status // empty')"
  autofill_remaining="$(echo "${autofill_order}" | jq -r '.remainingQuantity // -1')"
  if [[ "${autofill_status}" != "NEW" ]]; then
    autofill_first_remaining="${autofill_remaining}"
    break
  fi
  sleep 1
done
if [[ -z "${autofill_first_remaining}" ]]; then
  echo "[error] expected auto-fill order to progress from NEW on matcher ticks"
  exit 1
fi
case "${autofill_first_remaining}" in
  2500|1250|625|0) ;;
  *)
    echo "[error] auto-fill remaining quantity did not follow expected reduction policy, got ${autofill_first_remaining}"
    exit 1
    ;;
esac
autofill_terminal=0
for _ in {1..40}; do
  autofill_order="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/${autofill_order_id}")"
  autofill_status="$(echo "${autofill_order}" | jq -r '.status // empty')"
  if [[ "${autofill_status}" == "FILLED" ]]; then
    autofill_terminal=1
    break
  fi
  sleep 1
done
if [[ "${autofill_terminal}" -ne 1 ]]; then
  echo "[error] expected auto-fill order ${autofill_order_id} to reach FILLED"
  exit 1
fi

echo "[check] lifecycle metrics include create/cancel/force_fill counters"
metrics_after_lifecycle="$(curl -fsS "http://localhost:${ORDER_MATCHER_PORT}/metrics")"
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="create"\}' || {
  echo "[error] missing create event counter after lifecycle actions"
  exit 1
}
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="cancel"\}' || {
  echo "[error] missing cancel event counter after lifecycle actions"
  exit 1
}
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="force_fill"\}' || {
  echo "[error] missing force_fill event counter after lifecycle actions"
  exit 1
}
post_open_count="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/open-count" | jq -r '.openOrders')"
if [[ "${post_open_count}" != "${pre_open_count}" ]]; then
  echo "[error] open-order count drifted unexpectedly (before=${pre_open_count}, after=${post_open_count})"
  exit 1
fi
echo "[info] order lifecycle checks passed (open orders before=${pre_open_count}, after=${post_open_count})"

echo "[check] admin route served by web UI"
admin_headers="$(curl -sS -i "${INGRESS_URL}/admin" | sed -n '1,20p')"
echo "${admin_headers}"
printf '%s\n' "${admin_headers}" | grep -q "200" || {
  echo "[error] expected admin route to return 200"
  exit 1
}

echo "[done] state 013 order-management observability smoke tests passed"
