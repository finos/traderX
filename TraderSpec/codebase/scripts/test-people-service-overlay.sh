#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
BASE_URL="${2:-http://localhost:18089}"
ACCOUNT_USER_URL="${3:-http://localhost:18088/accountuser/}"

echo "[check] CORS header from ${BASE_URL}/People/GetMatchingPeople for origin ${ORIGIN}"
headers="$(curl -sS -i -H "Origin: ${ORIGIN}" "${BASE_URL}/People/GetMatchingPeople?SearchText=user&Take=1" | sed -n '1,30p')"
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

echo "[check] known person lookup"
person_json="$(curl -sS "${BASE_URL}/People/GetPerson?LogonId=user01")"
echo "${person_json}" | jq
logon_id="$(echo "${person_json}" | jq -r '.logonId')"
if [[ "${logon_id}" != "user01" ]]; then
  echo "[error] expected logonId=user01, got ${logon_id}"
  exit 1
fi

echo "[check] matching people response shape"
matching_json="$(curl -sS "${BASE_URL}/People/GetMatchingPeople?SearchText=user&Take=5")"
echo "${matching_json}" | jq
matching_count="$(echo "${matching_json}" | jq '.people | length')"
if [[ "${matching_count}" -lt 1 ]]; then
  echo "[error] expected at least one matching person, got ${matching_count}"
  exit 1
fi

echo "[check] validate known person"
known_validate_http_code="$(curl -sS -o /tmp/people-service-validate-known.out -w "%{http_code}" "${BASE_URL}/People/ValidatePerson?LogonId=user01")"
if [[ "${known_validate_http_code}" != "200" ]]; then
  echo "[error] expected 200 for known validation, got ${known_validate_http_code}"
  exit 1
fi

echo "[check] unknown person returns 404"
unknown_http_code="$(curl -sS -o /tmp/people-service-404.out -w "%{http_code}" "${BASE_URL}/People/GetPerson?LogonId=DOES_NOT_EXIST")"
if [[ "${unknown_http_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown person lookup, got ${unknown_http_code}"
  exit 1
fi

echo "[check] account-service accountuser endpoint still reachable"
curl -sS -i "${ACCOUNT_USER_URL}" | sed -n '1,20p'

echo "[done] people-service overlay smoke tests passed"
