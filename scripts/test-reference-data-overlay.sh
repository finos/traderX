#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
BASE_URL="${2:-http://localhost:18085}"
MIN_STOCK_COUNT="${3:-500}"

echo "[check] CORS header from ${BASE_URL}/stocks for origin ${ORIGIN}"
headers="$(curl -sS -i -H "Origin: ${ORIGIN}" "${BASE_URL}/stocks" | sed -n '1,30p')"
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

echo "[check] stocks list size"
stocks_count="$(curl -sS "${BASE_URL}/stocks" | jq 'length')"
echo "[info] stock count=${stocks_count}"
if [[ "${stocks_count}" -lt "${MIN_STOCK_COUNT}" ]]; then
  echo "[error] expected at least ${MIN_STOCK_COUNT} symbols, got ${stocks_count}"
  exit 1
fi

echo "[check] known ticker lookup"
ibm_json="$(curl -sS "${BASE_URL}/stocks/IBM")"
echo "${ibm_json}" | jq

echo "[check] unknown ticker returns 404"
http_code="$(curl -sS -o /tmp/reference-data-404.out -w "%{http_code}" "${BASE_URL}/stocks/DOES_NOT_EXIST")"
if [[ "${http_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker, got ${http_code}"
  exit 1
fi

echo "[done] reference-data overlay smoke tests passed"
