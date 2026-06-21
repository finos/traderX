#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi

INGRESS_URL="${1:-http://localhost:8080}"
SAIL_URL="${2:-http://localhost:8090}"
NAMESPACE="${3:-traderx}"
K8S_PROVIDER="${4:-${K8S_PROVIDER:-kind}}"
CLUSTER_OR_PROFILE="${5:-${MINIKUBE_PROFILE:-traderx-state-014}}"
EXPECTED_STATE="014-fdc3-intent-interoperability"

STATE_DIR="${GENERATED_ROOT}/code/target-generated/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_COMPOSE_FILE="${SAIL_DIR}/docker-compose.yml"
SAIL_PROJECT_NAME="${SAIL_PROJECT_NAME:-traderx-state-014-sail}"
SAIL_RUNTIME_APPD="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"

source "${REPO_ROOT}/scripts/lib/generated-state-detection.sh"

echo "[check] generated output state metadata"
traderx_report_generated_state "${EXPECTED_STATE}" "${GENERATED_ROOT}" >/dev/null || {
  echo "[error] generated output does not match expected state ${EXPECTED_STATE}"
  exit 1
}

echo "[check] state 012 baseline compatibility for state 014"
"${REPO_ROOT}/scripts/test-state-012-platform-convergence-c3.sh" "${INGRESS_URL}" "${NAMESPACE}" "${K8S_PROVIDER}" "${CLUSTER_OR_PROFILE}"

echo "[check] state 014 Sail artifact pack exists"
for required in \
  "${STATE_DIR}/README.md" \
  "${SAIL_COMPOSE_FILE}" \
  "${SAIL_DIR}/bootstrap/run-sail.sh" \
  "${SAIL_DIR}/bootstrap/apply-tradingview-overrides.sh" \
  "${SAIL_DIR}/bootstrap/overrides/tradingview/TradingViewWidget.tsx" \
  "${SAIL_DIR}/bootstrap/overrides/tradingview/modes/chart.ts" \
  "${SAIL_DIR}/bootstrap/overrides/tradingview/modes/symbol-info.ts" \
  "${SAIL_DIR}/bootstrap/overrides/tradingview/modes/fundamentals.ts" \
  "${SAIL_DIR}/bootstrap/overrides/tradingview/modes/symbol-compat.ts" \
  "${SAIL_DIR}/bootstrap/merge-traderx-appd.sh" \
  "${SAIL_DIR}/appd/traderx.appd.v2.json"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing expected state 014 artifact: ${required}"
    exit 1
  }
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found (required for Sail smoke checks)"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required for Sail smoke checks"
  exit 1
fi

echo "[check] Sail sidecar compose service is running"
docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" ps
running_services="$(docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 1 ]]; then
  echo "[error] expected Sail sidecar service to be running"
  exit 1
fi

echo "[check] Sail UI endpoint"
sail_headers="$(curl -sS -i "${SAIL_URL}/html/" | sed -n '1,20p')"
echo "${sail_headers}"
printf '%s\n' "${sail_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from Sail /html/"
  exit 1
}

if [[ ! -f "${SAIL_RUNTIME_APPD}" ]]; then
  echo "[error] missing Sail generated app directory: ${SAIL_RUNTIME_APPD}"
  exit 1
fi

echo "[check] Sail app directory contains TraderX handler metadata and demo apps"
node - "${SAIL_RUNTIME_APPD}" <<'NODE'
const fs = require("node:fs");
const appdPath = process.argv[2];
const doc = JSON.parse(fs.readFileSync(appdPath, "utf8"));
const apps = Array.isArray(doc.applications) ? doc.applications : [];

if (apps.length < 3) {
  throw new Error(`expected at least 3 apps in Sail directory, found ${apps.length}`);
}

const traderx = apps.find((app) => app.appId === "traderx-web");
if (!traderx) {
  throw new Error("missing traderx-web app record in Sail directory");
}

const traderxUrl = traderx?.details?.url;
if (typeof traderxUrl !== "string" || !traderxUrl.endsWith("/trade")) {
  throw new Error(`TraderX app URL should end with /trade; got ${traderxUrl}`);
}

const injectApiVersion = traderx?.hostManifests?.sail?.injectApi;
if (injectApiVersion !== "2.0") {
  throw new Error(`TraderX hostManifests.sail.injectApi should be 2.0; got ${injectApiVersion}`);
}

const listensFor =
  traderx?.interop?.intents?.listensFor ??
  traderx?.interop?.listensFor ??
  {};

for (const intentName of [
  "ViewOrders",
  "TraderX.CreateTradeTicket",
  "TraderX.CreateOrderTicket",
]) {
  if (!listensFor[intentName]) {
    throw new Error(`TraderX app record missing listensFor intent: ${intentName}`);
  }
}

const otherApps = apps.filter((app) => app.appId !== "traderx-web");
if (otherApps.length < 2) {
  throw new Error(`expected at least two non-TraderX demo apps, found ${otherApps.length}`);
}

console.log(`[ok] Sail directory apps=${apps.length}, traderx=true, demoApps=${otherApps.length}`);
NODE

echo "[check] Sail is directly reachable and not served from TraderX ingress"
ingress_sail_probe_file="$(mktemp)"
ingress_sail_code="$(curl -sS -o "${ingress_sail_probe_file}" -w "%{http_code}" "${INGRESS_URL}/html/" || true)"
if [[ "${ingress_sail_code}" == "200" ]] && rg -qi "fdc3 sail|FDC3 Sail|sail-client-state" "${ingress_sail_probe_file}"; then
  rm -f "${ingress_sail_probe_file}"
  echo "[error] Sail content appears to be reachable via TraderX ingress; expected sidecar-only endpoint"
  exit 1
fi
rm -f "${ingress_sail_probe_file}"

if [[ "${TRADERX_SKIP_FDC3_PLAYWRIGHT_SMOKE:-0}" == "1" ]]; then
  echo "[skip] playwright fdc3 smoke disabled (TRADERX_SKIP_FDC3_PLAYWRIGHT_SMOKE=1)"
else
  echo "[check] playwright fdc3 interop smoke"
  "${REPO_ROOT}/scripts/test-state-014-fdc3-playwright-smoke.sh" \
    "${INGRESS_URL%/}/trade" \
    "http://localhost:4023/?mode=fundamentals"
fi

echo "[done] state 014 FDC3 Sail smoke tests passed"
