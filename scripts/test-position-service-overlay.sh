#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
BASE_URL="${2:-http://localhost:18090}"

echo "[check] CORS header from ${BASE_URL}/positions/22214 for origin ${ORIGIN}"
headers="$(curl -sS -i -H "Origin: ${ORIGIN}" "${BASE_URL}/positions/22214" | sed -n '1,30p')"
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

echo "[check] positions by account"
positions_json="$(curl -sS "${BASE_URL}/positions/22214")"
echo "${positions_json}" | jq '.[0]'
positions_count="$(echo "${positions_json}" | jq 'length')"
if [[ "${positions_count}" -lt 1 ]]; then
  echo "[error] expected at least one position for account 22214"
  exit 1
fi

echo "[check] trades by account"
trades_json="$(curl -sS "${BASE_URL}/trades/22214")"
echo "${trades_json}" | jq '.[0]'
trades_count="$(echo "${trades_json}" | jq 'length')"
if [[ "${trades_count}" -lt 1 ]]; then
  echo "[error] expected at least one trade for account 22214"
  exit 1
fi

echo "[check] health ready"
ready_value="$(curl -sS "${BASE_URL}/health/ready" | jq -r '.')"
if [[ "${ready_value}" != "true" ]]; then
  echo "[error] expected /health/ready to be true, got ${ready_value}"
  exit 1
fi

echo "[check] health alive"
alive_value="$(curl -sS "${BASE_URL}/health/alive" | jq -r '.')"
if [[ "${alive_value}" != "true" ]]; then
  echo "[error] expected /health/alive to be true, got ${alive_value}"
  exit 1
fi

echo "[done] position-service overlay smoke tests passed"
