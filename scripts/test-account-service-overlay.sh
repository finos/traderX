#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
BASE_URL="${2:-http://localhost:18088}"

echo "[check] CORS header from ${BASE_URL}/account/22214 for origin ${ORIGIN}"
headers="$(curl -sS -i -H "Origin: ${ORIGIN}" "${BASE_URL}/account/22214" | sed -n '1,30p')"
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

echo "[check] known account lookup"
account_json="$(curl -sS "${BASE_URL}/account/22214")"
echo "${account_json}" | jq
account_id="$(echo "${account_json}" | jq -r '.id')"
if [[ "${account_id}" != "22214" ]]; then
  echo "[error] expected account id 22214, got ${account_id}"
  exit 1
fi

echo "[check] account list"
account_count="$(curl -sS "${BASE_URL}/account/" | jq 'length')"
echo "[info] account count=${account_count}"
if [[ "${account_count}" -lt 1 ]]; then
  echo "[error] expected at least one account"
  exit 1
fi

echo "[check] account-user list"
account_user_count="$(curl -sS "${BASE_URL}/accountuser/" | jq 'length')"
echo "[info] account-user count=${account_user_count}"
if [[ "${account_user_count}" -lt 1 ]]; then
  echo "[error] expected at least one account-user mapping"
  exit 1
fi

echo "[check] unknown username rejected by people-service validation"
unknown_http_code="$(
  curl -sS -o /tmp/account-service-unknown-user.out -w "%{http_code}" \
    -X POST "${BASE_URL}/accountuser/" \
    -H "Content-Type: application/json" \
    -d '{"accountId":22214,"username":"DOES_NOT_EXIST"}'
)"
if [[ "${unknown_http_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown person on accountuser create, got ${unknown_http_code}"
  exit 1
fi

echo "[done] account-service overlay smoke tests passed"
