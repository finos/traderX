#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
STATE_DIR="${TARGET_ROOT}/pricing-awareness-market-data"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"
INGRESS_FILE="${TARGET_ROOT}/ingress/nginx.traderx.conf.template"

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    echo "[fail] missing required file: ${path}"
    exit 1
  }
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
      print "        proxy_set_header Host $http_host;"
      print "        proxy_set_header X-Forwarded-Proto $scheme;"
      print "        proxy_set_header X-Forwarded-Prefix /grafana;"
      print "    }"
      print ""
      print "    location = /prometheus {"
      print "        return 301 /prometheus/;"
      print "    }"
      print ""
      print "    location /prometheus/ {"
      print "        proxy_pass http://prometheus:9090;"
      print "        proxy_http_version 1.1;"
      print "        proxy_set_header Host $http_host;"
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

require_file "${COMPOSE_FILE}"
require_file "${INGRESS_FILE}"

perl -0pi -e 's/^name:\s*traderx-state-\d+/name: traderx-state-008/m' "${COMPOSE_FILE}"

GEN_DEPTH="${TRADERX_GENERATION_DEPTH:-1}"
if [[ "${GEN_DEPTH}" == "1" ]]; then
  ensure_observability_ingress_routes "${INGRESS_FILE}"
else
  echo "[info] nested generation depth=${GEN_DEPTH}; skipping ingress observability route mutation"
fi

echo "[done] rendered state 008 pricing ingress + metadata refinements into ${STATE_DIR}"
