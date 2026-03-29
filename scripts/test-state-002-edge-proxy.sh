#!/usr/bin/env bash
set -euo pipefail

EDGE_URL="${1:-http://localhost:18080}"

echo "[check] edge-proxy health endpoint"
curl -sS -i "${EDGE_URL}/health" | sed -n '1,20p'

echo "[check] proxied UI root"
curl -sS -i "${EDGE_URL}/" | sed -n '1,20p'

echo "[check] proxied account-service endpoint"
account_headers="$(curl -sS -i "${EDGE_URL}/account-service/account/22214" | sed -n '1,25p')"
echo "${account_headers}"
printf '%s\n' "${account_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from proxied account-service endpoint"
  exit 1
}

echo "[check] proxied reference-data endpoint"
stocks_headers="$(curl -sS -i "${EDGE_URL}/reference-data/stocks" | sed -n '1,25p')"
echo "${stocks_headers}"
printf '%s\n' "${stocks_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from proxied reference-data endpoint"
  exit 1
}

echo "[check] proxied trade-service unknown ticker validation"
status_code="$(curl -sS -o /tmp/traderx-state-002-trade.out -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d '{"security":"NOTREAL","quantity":1,"accountId":22214,"side":"Buy"}' \
  "${EDGE_URL}/trade-service/trade")"
cat /tmp/traderx-state-002-trade.out
echo
rm -f /tmp/traderx-state-002-trade.out
if [[ "${status_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker via edge proxy, got ${status_code}"
  exit 1
fi

echo "[done] state 002 edge-proxy smoke tests passed"
