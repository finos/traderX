#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

START_COMPOSE=false
for arg in "$@"; do
  case "$arg" in
    --start-compose)
      START_COMPOSE=true
      ;;
  esac
done

if $START_COMPOSE; then
  (cd "$ROOT_DIR" && docker compose up -d \
    database trade-feed reference-data people-service \
    account-service position-service trade-service trade-processor)
fi

fetch_spec() {
  local name="$1"
  local url="$2"
  local output="$3"

  echo "Fetching ${name} OpenAPI spec from ${url}"
  for _ in $(seq 1 30); do
    if curl -fsS "$url" -o "${output}.tmp"; then
      if command -v jq >/dev/null 2>&1; then
        jq . "${output}.tmp" > "$output"
      else
        python3 -m json.tool "${output}.tmp" > "$output"
      fi
      rm -f "${output}.tmp"
      echo "Wrote ${output}"
      return 0
    fi
    sleep 2
  done

  echo "Failed to fetch ${name} OpenAPI spec after retries." >&2
  rm -f "${output}.tmp"
  return 1
}

fetch_spec "reference-data" "http://localhost:18085/api-json" "${ROOT_DIR}/reference-data/openapi.json"
fetch_spec "people-service" "http://localhost:18089/swagger/v1/swagger.json" "${ROOT_DIR}/people-service/openapi.json"
fetch_spec "account-service" "http://localhost:18088/v3/api-docs" "${ROOT_DIR}/account-service/openapi.json"
fetch_spec "position-service" "http://localhost:18090/v3/api-docs" "${ROOT_DIR}/position-service/openapi.json"
fetch_spec "trade-service" "http://localhost:18092/v3/api-docs" "${ROOT_DIR}/trade-service/openapi.json"
fetch_spec "trade-processor" "http://localhost:18091/v3/api-docs" "${ROOT_DIR}/trade-processor/openapi.json"

echo "OpenAPI specs refreshed."
