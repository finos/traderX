#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${1:-http://localhost:3001}"
GRAFANA_USER="${2:-admin}"
GRAFANA_PASSWORD="${3:-admin}"
DASHBOARD_QUERY="${4:-TraderX}"
HOME_DASHBOARD_UID="${5:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "[warn] jq not found; skipping Grafana starring"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[warn] curl not found; skipping Grafana starring"
  exit 0
fi

dashboards_json=""
for _ in {1..20}; do
  dashboards_json="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/search?query=${DASHBOARD_QUERY}&type=dash-db" 2>/dev/null || true)"
  count="$(printf '%s' "${dashboards_json}" | jq 'length' 2>/dev/null || echo 0)"
  if [[ "${count}" -gt 0 ]]; then
    break
  fi
  sleep 2
done

if [[ -z "${dashboards_json}" ]]; then
  echo "[warn] unable to query Grafana dashboards for starring"
  exit 0
fi

dashboard_ids="$(printf '%s' "${dashboards_json}" | jq -r '.[].id // empty')"
if [[ -z "${dashboard_ids}" ]]; then
  echo "[warn] no dashboards found for query '${DASHBOARD_QUERY}'"
  exit 0
fi

starred=0
for id in ${dashboard_ids}; do
  if curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" -X POST "${GRAFANA_URL}/api/user/stars/dashboard/${id}" >/dev/null 2>&1; then
    starred=$((starred + 1))
  fi
done

if [[ -n "${HOME_DASHBOARD_UID}" ]]; then
  curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X PUT \
    -d "{\"homeDashboardUID\":\"${HOME_DASHBOARD_UID}\"}" \
    "${GRAFANA_URL}/api/user/preferences" >/dev/null 2>&1 || true
fi

echo "[info] starred ${starred} Grafana dashboard(s) for query '${DASHBOARD_QUERY}'"
