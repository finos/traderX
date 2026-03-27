#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
TRADE_SERVICE_URL="${2:-http://localhost:18092}"
POSITION_SERVICE_URL="${3:-http://localhost:18090}"

ACCOUNT_ID=22214
QTY=$((4300 + RANDOM % 700))
SECURITY="IBM"
UNKNOWN_TICKER="NO_SUCH_TICKER_123"
UNKNOWN_ACCOUNT=99999999

echo "[check] CORS header from ${TRADE_SERVICE_URL}/trade/ for origin ${ORIGIN}"
headers="$(
  curl -sS -i -X OPTIONS \
    -H "Origin: ${ORIGIN}" \
    -H "Access-Control-Request-Method: POST" \
    "${TRADE_SERVICE_URL}/trade/" | sed -n '1,30p'
)"
echo "${headers}"

cors_header="$(printf '%s\n' "${headers}" | awk -F': ' 'tolower($1)=="access-control-allow-origin" {print $2}' | tr -d '\r' || true)"
if [[ -z "${cors_header}" ]]; then
  echo "[error] missing Access-Control-Allow-Origin header"
  exit 1
fi

if [[ "${cors_header}" != "*" && "${cors_header}" != "${ORIGIN}" ]]; then
  echo "[error] unexpected Access-Control-Allow-Origin value: ${cors_header}"
  exit 1
fi

echo "[check] valid trade submission is accepted"
valid_http_code="$(
  curl -sS -o /tmp/trade-service-valid.out -w "%{http_code}" \
    -X POST "${TRADE_SERVICE_URL}/trade/" \
    -H "Content-Type: application/json" \
    -d "{\"security\":\"${SECURITY}\",\"quantity\":${QTY},\"accountId\":${ACCOUNT_ID},\"side\":\"Buy\"}"
)"
if [[ "${valid_http_code}" != "200" ]]; then
  echo "[error] expected 200 for valid trade submit, got ${valid_http_code}"
  cat /tmp/trade-service-valid.out
  exit 1
fi

cat /tmp/trade-service-valid.out | jq
returned_account_id="$(jq -r '.accountId // .accountID // empty' /tmp/trade-service-valid.out)"
returned_security="$(jq -r '.security // empty' /tmp/trade-service-valid.out)"
returned_qty="$(jq -r '.quantity // empty' /tmp/trade-service-valid.out)"
if [[ "${returned_account_id}" != "${ACCOUNT_ID}" || "${returned_security}" != "${SECURITY}" || "${returned_qty}" != "${QTY}" ]]; then
  echo "[error] response payload mismatch from valid submit"
  exit 1
fi

echo "[check] processed trade appears in position-service trades view"
found_trade=0
for _ in $(seq 1 25); do
  trades_json="$(curl -sS "${POSITION_SERVICE_URL}/trades/${ACCOUNT_ID}")"
  if echo "${trades_json}" | jq -e --arg sec "${SECURITY}" --argjson qty "${QTY}" 'map(select(.security == $sec and .quantity == $qty and .state == "Settled")) | length > 0' >/dev/null; then
    found_trade=1
    break
  fi
  sleep 1
done
if [[ "${found_trade}" != "1" ]]; then
  echo "[error] expected settled downstream trade from trade-service submit (security=${SECURITY}, quantity=${QTY})"
  exit 1
fi

echo "[check] unknown ticker returns 404"
unknown_ticker_http_code="$(
  curl -sS -o /tmp/trade-service-unknown-ticker.out -w "%{http_code}" \
    -X POST "${TRADE_SERVICE_URL}/trade/" \
    -H "Content-Type: application/json" \
    -d "{\"security\":\"${UNKNOWN_TICKER}\",\"quantity\":100,\"accountId\":${ACCOUNT_ID},\"side\":\"Buy\"}"
)"
if [[ "${unknown_ticker_http_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker, got ${unknown_ticker_http_code}"
  cat /tmp/trade-service-unknown-ticker.out
  exit 1
fi

echo "[check] unknown account returns 404"
unknown_account_http_code="$(
  curl -sS -o /tmp/trade-service-unknown-account.out -w "%{http_code}" \
    -X POST "${TRADE_SERVICE_URL}/trade/" \
    -H "Content-Type: application/json" \
    -d "{\"security\":\"${SECURITY}\",\"quantity\":100,\"accountId\":${UNKNOWN_ACCOUNT},\"side\":\"Buy\"}"
)"
if [[ "${unknown_account_http_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown account, got ${unknown_account_http_code}"
  cat /tmp/trade-service-unknown-account.out
  exit 1
fi

echo "[done] trade-service overlay smoke tests passed"
