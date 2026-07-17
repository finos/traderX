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
SAIL_TRADERX_FIXTURE="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/sail-web/fixtures/traderx-appd.json"
SAIL_TRADINGVIEW_FIXTURE="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/sail-web/fixtures/tradingview-appd.json"
SAIL_TOOLBOX_APPD_URL="${SAIL_TOOLBOX_APPD_URL:-http://localhost:4005/static/generated/fdc3-example-apps.json}"
TRADERX_FRONTEND_APPD="${GENERATED_ROOT}/code/target-generated/web-front-end/angular/main/fdc3/appd/v2/apps"
TRADERX_APPD_URL="${INGRESS_URL%/}/fdc3/appd/v2/apps"

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
  "${SAIL_DIR}/bootstrap/apply-sail-demo-compat.sh" \
  "${SAIL_DIR}/bootstrap/patch-fdc3-example-apps.sh" \
  "${SAIL_DIR}/bootstrap/merge-traderx-appd.sh" \
  "${TRADERX_FRONTEND_APPD}" \
  "${SAIL_DIR}/appd/traderx.appd.v2.json"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing expected state 014 artifact: ${required}"
    exit 1
  }
done

grep -q "joinUserChannel(demoChannel.id)" "${SAIL_DIR}/bootstrap/patch-fdc3-example-apps.sh" || {
  echo "[error] expected TradingView toolbox patch to join the demo user channel"
  exit 1
}
grep -q "syncCurrentInstrument" "${SAIL_DIR}/bootstrap/patch-fdc3-example-apps.sh" || {
  echo "[error] expected TradingView toolbox patch to sync current channel context"
  exit 1
}
grep -q "replaceChildren" "${SAIL_DIR}/bootstrap/patch-fdc3-example-apps.sh" || {
  echo "[error] expected TradingView toolbox patch to clear stale embedded widgets on context changes"
  exit 1
}

echo "[check] TraderX-owned AppD endpoint"
traderx_appd_file="$(mktemp)"
traderx_appd_code="$(curl -sS -o "${traderx_appd_file}" -w "%{http_code}" "${TRADERX_APPD_URL}" || true)"
if [[ "${traderx_appd_code}" != "200" ]]; then
  rm -f "${traderx_appd_file}"
  echo "[error] expected 200 from TraderX AppD endpoint ${TRADERX_APPD_URL}, got ${traderx_appd_code}"
  exit 1
fi

traderx_appd_headers="$(curl -sS -i -H "Origin: ${SAIL_URL%/}" "${TRADERX_APPD_URL}" | sed -n '1,/^\r$/p')"
printf '%s\n' "${traderx_appd_headers}" | grep -qi '^access-control-allow-origin:' || {
  rm -f "${traderx_appd_file}"
  echo "[error] TraderX AppD endpoint must allow Sail browser-origin reads"
  exit 1
}

node - "${traderx_appd_file}" <<'NODE'
const fs = require("node:fs");
const appdPath = process.argv[2];
const doc = JSON.parse(fs.readFileSync(appdPath, "utf8"));
const apps = Array.isArray(doc.applications) ? doc.applications : [];
const byId = new Map(apps.map((app) => [app.appId, app]));
for (const appId of ["traderx-web", "traderx-mini", "traderx-intent-launcher"]) {
  if (!byId.has(appId)) {
    throw new Error(`TraderX AppD endpoint missing ${appId}`);
  }
}

const traderxUrl = byId.get("traderx-web")?.details?.url;
if (traderxUrl !== "http://localhost:8080/trade") {
  throw new Error(`expected traderx-web URL http://localhost:8080/trade, got ${traderxUrl}`);
}

const mini = byId.get("traderx-mini");
const miniListensFor = mini?.interop?.intents?.listensFor ?? {};
if (Object.keys(miniListensFor).length !== 0) {
  throw new Error("Mini TraderX should not advertise trade/order ticket intent handling");
}

const launcherRaises = byId.get("traderx-intent-launcher")?.interop?.intents?.raises ?? {};
for (const intentName of ["TraderX.CreateTradeTicket", "TraderX.CreateOrderTicket"]) {
  if (!launcherRaises[intentName]) {
    throw new Error(`TraderX intent launcher should advertise raised intent ${intentName}`);
  }
}

console.log(`[ok] TraderX AppD endpoint apps=${apps.length}`);
NODE
rm -f "${traderx_appd_file}"

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
sail_headers="$(curl -sS -i "${SAIL_URL}/" | sed -n '1,20p')"
echo "${sail_headers}"
printf '%s\n' "${sail_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from Sail /"
  exit 1
}

echo "[check] FDC3 toolbox TradingView page is compact when framed"
tradingview_html="$(curl -sS "http://localhost:4023/?mode=chart")"
if printf '%s\n' "${tradingview_html}" | grep -Eq 'class="app-(title|subtitle)"'; then
  echo "[error] expected patched TradingView toolbox page to omit in-frame title/subtitle chrome"
  exit 1
fi

if [[ ! -f "${SAIL_TRADERX_FIXTURE}" ]]; then
  echo "[error] missing Sail TraderX fixture: ${SAIL_TRADERX_FIXTURE}"
  exit 1
fi
if [[ ! -f "${SAIL_TRADINGVIEW_FIXTURE}" ]]; then
  echo "[error] missing Sail TradingView fixture: ${SAIL_TRADINGVIEW_FIXTURE}"
  exit 1
fi

echo "[check] Sail TraderX fixture contains TraderX FDC3 v3 handler metadata"
node - "${SAIL_TRADERX_FIXTURE}" <<'NODE'
const fs = require("node:fs");
const appdPath = process.argv[2];
const doc = JSON.parse(fs.readFileSync(appdPath, "utf8"));
const apps = Array.isArray(doc.applications) ? doc.applications : [];

if (apps.length < 1) {
  throw new Error(`expected at least 1 app in Sail TraderX fixture, found ${apps.length}`);
}

const traderx = apps.find((app) => app.appId === "traderx-web");
if (!traderx) {
  throw new Error("missing traderx-web app record in Sail directory");
}
const miniTraderx = apps.find((app) => app.appId === "traderx-mini");
if (!miniTraderx) {
  throw new Error("missing traderx-mini app record in Sail directory");
}
const launcher = apps.find((app) => app.appId === "traderx-intent-launcher");
if (!launcher) {
  throw new Error("missing traderx-intent-launcher app record in Sail directory");
}

const traderxUrl = traderx?.details?.url;
if (typeof traderxUrl !== "string" || !traderxUrl.endsWith("/trade")) {
  throw new Error(`TraderX app URL should end with /trade; got ${traderxUrl}`);
}
const miniTraderxUrl = miniTraderx?.details?.url;
if (typeof miniTraderxUrl !== "string" || !miniTraderxUrl.endsWith("/mini-traderx")) {
  throw new Error(`Mini TraderX app URL should end with /mini-traderx; got ${miniTraderxUrl}`);
}
const launcherUrl = launcher?.details?.url;
if (typeof launcherUrl !== "string" || !launcherUrl.endsWith(":4040/")) {
  throw new Error(`TraderX launcher URL should point at localhost:4040; got ${launcherUrl}`);
}

const hostManifests = traderx?.hostManifests ?? {};
if (hostManifests.sail?.injectApi || hostManifests.sail?.["inject-api"]) {
  throw new Error("TraderX should use standard FDC3 v3 getAgent discovery, not Sail API injection metadata");
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

const traderxUserChannels = traderx?.interop?.userChannels ?? {};
const miniUserChannels = miniTraderx?.interop?.userChannels ?? {};
for (const app of [
  { name: "TraderX", channels: traderxUserChannels },
  { name: "Mini TraderX", channels: miniUserChannels },
]) {
  const broadcasts = Array.isArray(app.channels.broadcasts) ? app.channels.broadcasts : [];
  const listensFor = Array.isArray(app.channels.listensFor) ? app.channels.listensFor : [];
  for (const contextType of ["fdc3.instrument", "traderx.account"]) {
    if (!broadcasts.includes(contextType)) {
      throw new Error(`${app.name} app record missing userChannels.broadcasts ${contextType}`);
    }
    if (!listensFor.includes(contextType)) {
      throw new Error(`${app.name} app record missing userChannels.listensFor ${contextType}`);
    }
  }
}

console.log(`[ok] Sail TraderX fixture apps=${apps.length}, traderx=true, mini=true, launcher=true`);
NODE

echo "[check] Sail TradingView fixture synchronously seeds demo AppD records"
node - "${SAIL_TRADINGVIEW_FIXTURE}" <<'NODE'
const fs = require("node:fs");
const appdPath = process.argv[2];
const doc = JSON.parse(fs.readFileSync(appdPath, "utf8"));
const apps = Array.isArray(doc.applications) ? doc.applications : [];
for (const appId of ["trading-view-symbol-info-1", "trading-view-chart-1", "trading-view-fundamentals-1"]) {
  const app = apps.find(candidate => candidate.appId === appId);
  if (!app) {
    throw new Error(`missing ${appId} from synchronous TradingView fixture`);
  }
  const listensFor = app.interop?.userChannels?.listensFor ?? [];
  if (!Array.isArray(listensFor) || !listensFor.includes("fdc3.instrument")) {
    throw new Error(`${appId} should listen for fdc3.instrument on user channels`);
  }
}
console.log(`[ok] Sail TradingView fixture apps=${apps.length}`);
NODE

echo "[check] FDC3 toolbox AppD exposes TradingView/Pricer apps"
toolbox_appd_file="$(mktemp)"
toolbox_appd_code="$(curl -sS -o "${toolbox_appd_file}" -w "%{http_code}" "${SAIL_TOOLBOX_APPD_URL}" || true)"
if [[ "${toolbox_appd_code}" != "200" ]]; then
  rm -f "${toolbox_appd_file}"
  echo "[error] expected 200 from FDC3 toolbox AppD endpoint ${SAIL_TOOLBOX_APPD_URL}, got ${toolbox_appd_code}"
  exit 1
fi

node - "${toolbox_appd_file}" <<'NODE'
const fs = require("node:fs");
const appdPath = process.argv[2];
const doc = JSON.parse(fs.readFileSync(appdPath, "utf8"));
const apps = Array.isArray(doc.applications) ? doc.applications : [];
const byId = new Map(apps.map((app) => [app.appId, app]));

for (const appId of ["trading-view-chart-1", "trading-view-market-data-1", "pricer"]) {
  if (!byId.has(appId)) {
    throw new Error(`FDC3 toolbox AppD missing ${appId}`);
  }
}

const chartUrl = byId.get("trading-view-chart-1")?.details?.url;
if (typeof chartUrl !== "string" || !chartUrl.includes("localhost:4023") || !chartUrl.includes("mode=chart")) {
  throw new Error(`TradingView chart URL should point at localhost:4023/?mode=chart; got ${chartUrl}`);
}

const marketDataUrl = byId.get("trading-view-market-data-1")?.details?.url;
if (typeof marketDataUrl !== "string" || !marketDataUrl.includes("localhost:4023") || !marketDataUrl.includes("mode=market-data")) {
  throw new Error(`TradingView market data URL should point at localhost:4023/?mode=market-data; got ${marketDataUrl}`);
}

const pricerUrl = byId.get("pricer")?.details?.url;
if (typeof pricerUrl !== "string" || !pricerUrl.endsWith(":4020/")) {
  throw new Error(`Pricer URL should point at localhost:4020; got ${pricerUrl}`);
}

for (const appId of ["trading-view-chart-1", "trading-view-market-data-1", "trading-view-symbol-info-1", "trading-view-fundamentals-1"]) {
  const listensFor = byId.get(appId)?.interop?.userChannels?.listensFor ?? [];
  if (!Array.isArray(listensFor) || !listensFor.includes("fdc3.instrument")) {
    throw new Error(`${appId} should advertise userChannels.listensFor fdc3.instrument`);
  }
}

console.log(`[ok] FDC3 toolbox AppD apps=${apps.length}, tradingview=true, pricer=true`);
NODE
rm -f "${toolbox_appd_file}"

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
  TRADERX_SAIL_URL="${SAIL_URL}" \
  TRADERX_SAIL_TRADINGVIEW_URL="http://localhost:4023/?mode=chart" \
  TRADERX_SAIL_PRICER_URL="http://localhost:4020/" \
    "${REPO_ROOT}/scripts/test-state-014-fdc3-playwright-smoke.sh" \
    "${INGRESS_URL%/}/trade" \
    "http://localhost:4023/?mode=chart"
fi

echo "[done] state 014 FDC3 Sail smoke tests passed"
