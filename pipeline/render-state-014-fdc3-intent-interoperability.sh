#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_SPEC_DIR="${ROOT}/specs/014-fdc3-intent-interoperability"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
UPSTREAM_DIR="${TARGET_ROOT}/tilt-kubernetes-dev-loop"
STATE_DIR="${TARGET_ROOT}/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_BOOTSTRAP_DIR="${SAIL_DIR}/bootstrap"
SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_DIR="${SAIL_BOOTSTRAP_DIR}/overrides/tradingview"
SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_MODES_DIR="${SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_DIR}/modes"
SAIL_BOOTSTRAP_POLYGON_OVERRIDE_DIR="${SAIL_BOOTSTRAP_DIR}/overrides/polygon"
SAIL_BOOTSTRAP_WEB_OVERRIDE_DIR="${SAIL_BOOTSTRAP_DIR}/overrides/web"
SAIL_BOOTSTRAP_WEB_OVERRIDE_SRC_CLIENT_DIR="${SAIL_BOOTSTRAP_WEB_OVERRIDE_DIR}/src/client"
SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR="${SAIL_BOOTSTRAP_DIR}/overrides/traderx-intent-launcher"
SAIL_APPD_DIR="${SAIL_DIR}/appd"
SAIL_CACHE_DIR="${SAIL_DIR}/runtime-cache"
SAIL_TRADINGVIEW_WIDGET_OVERRIDE_SOURCE_FILE="${STATE_SPEC_DIR}/generation/sail-overrides/tradingview/TradingViewWidget.tsx"
SAIL_TRADINGVIEW_MODES_OVERRIDE_SOURCE_DIR="${STATE_SPEC_DIR}/generation/sail-overrides/tradingview/modes"
SAIL_POLYGON_WIDGET_OVERRIDE_SOURCE_FILE="${STATE_SPEC_DIR}/generation/sail-overrides/polygon/PolygonWidget.tsx"
SAIL_WEB_DEFAULT_STATE_SOURCE_FILE="${STATE_SPEC_DIR}/generation/sail-overrides/web/default-client-state.json"
SAIL_WEB_CLIENT_INDEX_OVERRIDE_SOURCE_FILE="${STATE_SPEC_DIR}/generation/sail-overrides/web/src/client/index.tsx"
SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR="${STATE_SPEC_DIR}/generation/sail-overrides/traderx-intent-launcher"
SAIL_PIN_SOURCE_FILE="${STATE_SPEC_DIR}/generation/sail-pin.env"
SAIL_PIN_TARGET_FILE="${SAIL_BOOTSTRAP_DIR}/sail-pin.env"
FRONTEND_OVERRIDE_SOURCE_DIR="${STATE_SPEC_DIR}/generation/frontend-overrides/web-front-end/angular"
TARGET_FRONTEND_DIR="${TARGET_ROOT}/web-front-end/angular"
UPSTREAM_BUILD_PLAN="${UPSTREAM_DIR}/upstream-build-plan.json"

for required in "${UPSTREAM_DIR}/README.md" "${UPSTREAM_DIR}/tilt/Tiltfile"; do
  [[ -e "${required}" ]] || {
    echo "[fail] required state 012 artifact missing for state 014 render: ${required}"
    exit 1
  }
done

rm -rf "${STATE_DIR}"
mkdir -p \
  "${SAIL_BOOTSTRAP_DIR}" \
  "${SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_MODES_DIR}" \
  "${SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_DIR}" \
  "${SAIL_BOOTSTRAP_POLYGON_OVERRIDE_DIR}" \
  "${SAIL_BOOTSTRAP_WEB_OVERRIDE_DIR}" \
  "${SAIL_BOOTSTRAP_WEB_OVERRIDE_SRC_CLIENT_DIR}" \
  "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/static" \
  "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/src" \
  "${SAIL_APPD_DIR}" \
  "${SAIL_CACHE_DIR}" \
  "${STATE_DIR}/spec-source"

if [[ -f "${UPSTREAM_BUILD_PLAN}" ]]; then
  cp "${UPSTREAM_BUILD_PLAN}" "${STATE_DIR}/upstream-build-plan.json"
fi

for source in spec.md requirements/functional-delta.md requirements/nonfunctional-delta.md contracts/contract-delta.md; do
  src_path="${ROOT}/specs/014-fdc3-intent-interoperability/${source}"
  [[ -f "${src_path}" ]] || continue
  cp "${src_path}" "${STATE_DIR}/spec-source/$(basename "${source}")"
done

cat > "${STATE_DIR}/README.md" <<'EOF'
# State 014 FDC3 Intent Interoperability Artifacts

Generated from:

- `specs/014-fdc3-intent-interoperability/**`
- inherited runtime from `generated/code/target-generated/tilt-kubernetes-dev-loop`

State intent:

- preserve state 012 runtime behavior,
- add a local Sail sidecar with seeded TraderX AppD metadata for FDC3 demo flows.

Artifacts:

- Sail sidecar compose: `sail/docker-compose.yml`
- Sail bootstrap scripts: `sail/bootstrap/*.sh`
- Sail pin manifest: `sail/bootstrap/sail-pin.env`
- Sail TradingView widget override: `sail/bootstrap/overrides/tradingview/TradingViewWidget.tsx`
- Sail TradingView mode overrides: `sail/bootstrap/overrides/tradingview/modes/*.ts`
- Sail Polygon news widget override: `sail/bootstrap/overrides/polygon/PolygonWidget.tsx`
- Sail TraderX intents launcher override app: `sail/bootstrap/overrides/traderx-intent-launcher/**`
- Sail default client-state snapshot: `sail/bootstrap/overrides/web/default-client-state.json`
- Sail web client bootstrap override: `sail/bootstrap/overrides/web/src/client/index.tsx`
- TraderX app directory overlay: `sail/appd/traderx.appd.v2.json`
- Sail runtime cache root: `sail/runtime-cache/`

Run baseline C3 runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --without-sail
```

Run C3 + Sail demo runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-014-fdc3-intent-interoperability.sh http://localhost:8080 http://localhost:8090
```

Demo script (two-tab profile):

1. Open Sail at `http://localhost:8090/html/` and verify two tabs:
   - `One`: chart + pricing + `traderx-intent-launcher` controls
   - `Two`: news app.
2. In tab `One`, use `Create Trade Ticket` and `Create Order Ticket`.
3. Confirm TraderX (`http://localhost:8080/trade`) opens the matching ticket with ticker prefilled.
4. Switch to tab `Two` and confirm news remains aligned to the active ticker context.
5. Change selected ticker in TraderX blotters and verify Sail apps update via `fdc3.instrument`.

Known demo workarounds / technical debt:

- TraderX publishes canonical bare ticker payloads only (`fdc3.instrument.id.ticker`).
- TraderX may use a bounded active-channel context-sync fallback to compensate for inconsistent demo-agent callback delivery; remove when robust Sail event delivery is available.
EOF

cat > "${SAIL_DIR}/docker-compose.yml" <<'EOF'
name: traderx-state-014-sail

services:
  sail:
    image: node:20-bookworm
    working_dir: /workspace/runtime-cache
    restart: unless-stopped
    environment:
      SAIL_REPO_URL: "${SAIL_REPO_URL:-https://github.com/finos/FDC3-Sail.git}"
      SAIL_REPO_REF: "${SAIL_REPO_REF:-4990547b06090eee167bbcadf850844e458babd5}"
      SAIL_REPO_COMMIT: "${SAIL_REPO_COMMIT:-}"
      SAIL_TRADERX_URL: "${SAIL_TRADERX_URL:-http://localhost:8080}"
      SAIL_HTTP_PORT: "${SAIL_HTTP_PORT:-8090}"
      SAIL_EXAMPLE_PORT_RANGE_START: "${SAIL_EXAMPLE_PORT_RANGE_START:-4010}"
      SAIL_EXAMPLE_PORT_RANGE_END: "${SAIL_EXAMPLE_PORT_RANGE_END:-4065}"
    command: ["/bin/bash", "/workspace/bootstrap/run-sail.sh"]
    volumes:
      - ./runtime-cache:/workspace/runtime-cache
      - ./bootstrap:/workspace/bootstrap:ro
      - ./appd:/workspace/appd:ro
    ports:
      - "${SAIL_HTTP_PORT:-8090}:8090"
      - "${SAIL_EXAMPLE_PORT_RANGE_START:-4010}-${SAIL_EXAMPLE_PORT_RANGE_END:-4065}:4010-4065"
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAIL_PIN_FILE="${SAIL_PIN_FILE:-/workspace/bootstrap/sail-pin.env}"
if [[ -f "${SAIL_PIN_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${SAIL_PIN_FILE}"
fi

SAIL_REPO_URL="${SAIL_REPO_URL:-${SAIL_PIN_REPO_URL:-https://github.com/finos/FDC3-Sail.git}}"
SAIL_REPO_REF="${SAIL_REPO_REF:-${SAIL_PIN_REPO_REF:-${SAIL_PINNED_REF:-${SAIL_PIN_TRACKING_REF:-main}}}}"
SAIL_REPO_REF="${SAIL_REPO_REF#origin/}"
SAIL_REPO_COMMIT="${SAIL_REPO_COMMIT:-${SAIL_PIN_REPO_COMMIT:-${SAIL_PINNED_REF:-}}}"
SAIL_REPO_DIR="${SAIL_REPO_DIR:-/workspace/runtime-cache/FDC3-Sail}"
SAIL_TRADERX_URL="${SAIL_TRADERX_URL:-http://localhost:8080}"
SAIL_APPD_BASE="${SAIL_REPO_DIR}/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"
SAIL_TRADERX_APPD="/workspace/appd/traderx.appd.v2.json"

mkdir -p "$(dirname "${SAIL_REPO_DIR}")"

if [[ ! -d "${SAIL_REPO_DIR}/.git" ]]; then
  if [[ -n "${SAIL_REPO_COMMIT}" ]]; then
    echo "[info] cloning Sail repository (pinned commit ${SAIL_REPO_COMMIT})"
    git clone "${SAIL_REPO_URL}" "${SAIL_REPO_DIR}"
    git -C "${SAIL_REPO_DIR}" checkout --force "${SAIL_REPO_COMMIT}"
  else
    echo "[info] cloning Sail repository (${SAIL_REPO_REF})"
    git clone --depth 1 --branch "${SAIL_REPO_REF}" "${SAIL_REPO_URL}" "${SAIL_REPO_DIR}"
  fi
else
  if [[ -n "${SAIL_REPO_COMMIT}" ]]; then
    echo "[info] updating Sail repository (pinned commit ${SAIL_REPO_COMMIT})"
    git -C "${SAIL_REPO_DIR}" fetch --prune origin
    git -C "${SAIL_REPO_DIR}" checkout --force "${SAIL_REPO_COMMIT}"
  else
    echo "[info] updating Sail repository (${SAIL_REPO_REF})"
    git -C "${SAIL_REPO_DIR}" fetch --depth 1 origin "${SAIL_REPO_REF}"
    git -C "${SAIL_REPO_DIR}" checkout --force FETCH_HEAD
  fi
fi

cd "${SAIL_REPO_DIR}"

if [[ -x /workspace/bootstrap/apply-tradingview-overrides.sh ]]; then
  echo "[info] applying state-014 Sail overrides"
  /workspace/bootstrap/apply-tradingview-overrides.sh "${SAIL_REPO_DIR}"
fi

echo "[info] installing Sail dependencies"
rm -rf node_modules
npm install --no-audit --no-fund

echo "[info] building Sail workspace packages required by web desktop agent"
npm run build -w packages/da-impl --if-present
npm run build -w packages/common --if-present

echo "[start] launching Sail example apps (directory generator)"
npm run examples:dev &
EXAMPLES_PID=$!

wait_for_file() {
  local path="$1"
  local attempts="$2"
  local i
  for ((i=1; i<=attempts; i++)); do
    if [[ -s "${path}" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! wait_for_file "${SAIL_APPD_BASE}" 180; then
  echo "[error] timeout waiting for generated Sail app directory: ${SAIL_APPD_BASE}"
  kill "${EXAMPLES_PID}" >/dev/null 2>&1 || true
  exit 1
fi

echo "[info] merging TraderX app record into Sail generated directory"
/workspace/bootstrap/merge-traderx-appd.sh "${SAIL_APPD_BASE}" "${SAIL_TRADERX_APPD}" "${SAIL_TRADERX_URL}"

reconcile_traderx_overlay() {
  while true; do
    if [[ -s "${SAIL_APPD_BASE}" ]]; then
      /workspace/bootstrap/merge-traderx-appd.sh "${SAIL_APPD_BASE}" "${SAIL_TRADERX_APPD}" "${SAIL_TRADERX_URL}" || true
    fi
    sleep 5
  done
}

reconcile_traderx_overlay &
RECONCILE_PID=$!

echo "[start] launching Sail web desktop agent"
npm run web:dev &
WEB_PID=$!

cleanup() {
  kill "${RECONCILE_PID}" >/dev/null 2>&1 || true
  kill "${WEB_PID}" >/dev/null 2>&1 || true
  kill "${EXAMPLES_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

set +e
wait -n "${EXAMPLES_PID}" "${WEB_PID}"
status="$?"
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[error] Sail process exited unexpectedly (status=${status})"
fi
exit "${status}"
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/apply-tradingview-overrides.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAIL_REPO_DIR="${1:-/workspace/runtime-cache/FDC3-Sail}"
OVERRIDE_TRADINGVIEW_WIDGET="/workspace/bootstrap/overrides/tradingview/TradingViewWidget.tsx"
TARGET_TRADINGVIEW_WIDGET="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/tradingview/src/TradingViewWidget.tsx"
OVERRIDE_TRADINGVIEW_MODES_DIR="/workspace/bootstrap/overrides/tradingview/modes"
TARGET_TRADINGVIEW_MODES_DIR="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/tradingview/src/modes"
OVERRIDE_POLYGON_WIDGET="/workspace/bootstrap/overrides/polygon/PolygonWidget.tsx"
TARGET_POLYGON_WIDGET="${SAIL_REPO_DIR}/packages/fdc3-example-apps/server-apps/polygon/src/PolygonWidget.tsx"
OVERRIDE_WEB_DEFAULT_STATE="/workspace/bootstrap/overrides/web/default-client-state.json"
TARGET_WEB_DEFAULT_STATE="${SAIL_REPO_DIR}/packages/web/default-client-state.json"
OVERRIDE_WEB_CLIENT_INDEX="/workspace/bootstrap/overrides/web/src/client/index.tsx"
TARGET_WEB_CLIENT_INDEX="${SAIL_REPO_DIR}/packages/web/src/client/index.tsx"
OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR="/workspace/bootstrap/overrides/traderx-intent-launcher"
TARGET_TRADERX_INTENT_LAUNCHER_DIR="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/traderx-intent-launcher"

if [[ -f "${OVERRIDE_TRADINGVIEW_WIDGET}" ]]; then
  mkdir -p "$(dirname "${TARGET_TRADINGVIEW_WIDGET}")"
  cp "${OVERRIDE_TRADINGVIEW_WIDGET}" "${TARGET_TRADINGVIEW_WIDGET}"
  echo "[ok] applied TradingView widget override to ${TARGET_TRADINGVIEW_WIDGET}"
fi

if compgen -G "${OVERRIDE_TRADINGVIEW_MODES_DIR}/*.ts" > /dev/null; then
  mkdir -p "${TARGET_TRADINGVIEW_MODES_DIR}"
  cp "${OVERRIDE_TRADINGVIEW_MODES_DIR}/"*.ts "${TARGET_TRADINGVIEW_MODES_DIR}/"
  echo "[ok] applied TradingView mode overrides to ${TARGET_TRADINGVIEW_MODES_DIR}"
fi

if [[ -f "${OVERRIDE_POLYGON_WIDGET}" ]]; then
  mkdir -p "$(dirname "${TARGET_POLYGON_WIDGET}")"
  cp "${OVERRIDE_POLYGON_WIDGET}" "${TARGET_POLYGON_WIDGET}"
  echo "[ok] applied Polygon widget override to ${TARGET_POLYGON_WIDGET}"
fi

if [[ -f "${OVERRIDE_WEB_DEFAULT_STATE}" ]]; then
  mkdir -p "$(dirname "${TARGET_WEB_DEFAULT_STATE}")"
  cp "${OVERRIDE_WEB_DEFAULT_STATE}" "${TARGET_WEB_DEFAULT_STATE}"
  echo "[ok] applied Sail demo default client state to ${TARGET_WEB_DEFAULT_STATE}"
fi

if [[ -f "${OVERRIDE_WEB_CLIENT_INDEX}" ]]; then
  mkdir -p "$(dirname "${TARGET_WEB_CLIENT_INDEX}")"
  cp "${OVERRIDE_WEB_CLIENT_INDEX}" "${TARGET_WEB_CLIENT_INDEX}"
  echo "[ok] applied Sail web client bootstrap override to ${TARGET_WEB_CLIENT_INDEX}"
fi

if [[ -d "${OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR}" ]]; then
  rm -rf "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
  mkdir -p "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
  cp -R "${OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR}/." "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}/"
  echo "[ok] applied TraderX intents launcher app override to ${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
fi
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/merge-traderx-appd.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BASE_FILE="${1:-}"
OVERLAY_FILE="${2:-}"
TRADERX_URL="${3:-http://localhost:8080}"

if [[ -z "${BASE_FILE}" || -z "${OVERLAY_FILE}" ]]; then
  echo "usage: merge-traderx-appd.sh <base-file> <overlay-file> [traderx-url]"
  exit 1
fi

node - "${BASE_FILE}" "${OVERLAY_FILE}" "${TRADERX_URL}" <<'NODE'
const fs = require("node:fs");

const [basePath, overlayPath, traderxUrl] = process.argv.slice(2);

const replaceTokens = (value) => {
  if (typeof value === "string") {
    return value.replaceAll("__TRADERX_URL__", traderxUrl);
  }
  if (Array.isArray(value)) {
    return value.map(replaceTokens);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, replaceTokens(v)]),
    );
  }
  return value;
};

const baseDoc = JSON.parse(fs.readFileSync(basePath, "utf8"));
const overlayDoc = replaceTokens(JSON.parse(fs.readFileSync(overlayPath, "utf8")));
const baseApps = Array.isArray(baseDoc.applications) ? baseDoc.applications : [];
const overlayApps = Array.isArray(overlayDoc.applications) ? overlayDoc.applications : [];

const mergedById = new Map();
for (const app of baseApps) {
  if (app && app.appId) mergedById.set(app.appId, app);
}
for (const app of overlayApps) {
  if (app && app.appId) mergedById.set(app.appId, app);
}

const mergedDoc = {
  ...baseDoc,
  applications: Array.from(mergedById.values()),
  message: baseDoc.message ?? "OK",
};

const next = `${JSON.stringify(mergedDoc, null, 2)}\n`;
const prev = fs.readFileSync(basePath, "utf8");
if (prev === next) {
  console.log(`[ok] TraderX AppD already current in ${basePath} (${mergedDoc.applications.length} apps)`);
  process.exit(0);
}
fs.writeFileSync(basePath, next, "utf8");
console.log(`[ok] merged TraderX AppD into ${basePath} (${mergedDoc.applications.length} apps)`);
NODE
EOF

for required in \
  "${SAIL_PIN_SOURCE_FILE}" \
  "${SAIL_POLYGON_WIDGET_OVERRIDE_SOURCE_FILE}" \
  "${SAIL_WEB_DEFAULT_STATE_SOURCE_FILE}" \
  "${SAIL_WEB_CLIENT_INDEX_OVERRIDE_SOURCE_FILE}" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/index.html" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/properties.json" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/static/appd.v2.json" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/static/icon.svg" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/src/main.tsx" \
  "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/src/main.module.css"; do
  [[ -f "${required}" ]] || {
    echo "[fail] missing required state 014 Sail override source: ${required}"
    exit 1
  }
done
cp "${SAIL_PIN_SOURCE_FILE}" "${SAIL_PIN_TARGET_FILE}"
if [[ -f "${SAIL_TRADINGVIEW_WIDGET_OVERRIDE_SOURCE_FILE}" ]]; then
  cp "${SAIL_TRADINGVIEW_WIDGET_OVERRIDE_SOURCE_FILE}" "${SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_DIR}/TradingViewWidget.tsx"
fi
if compgen -G "${SAIL_TRADINGVIEW_MODES_OVERRIDE_SOURCE_DIR}/*.ts" > /dev/null; then
  cp "${SAIL_TRADINGVIEW_MODES_OVERRIDE_SOURCE_DIR}/"*.ts "${SAIL_BOOTSTRAP_TRADINGVIEW_OVERRIDE_MODES_DIR}/"
fi
cp "${SAIL_POLYGON_WIDGET_OVERRIDE_SOURCE_FILE}" "${SAIL_BOOTSTRAP_POLYGON_OVERRIDE_DIR}/PolygonWidget.tsx"
cp "${SAIL_WEB_DEFAULT_STATE_SOURCE_FILE}" "${SAIL_BOOTSTRAP_WEB_OVERRIDE_DIR}/default-client-state.json"
cp "${SAIL_WEB_CLIENT_INDEX_OVERRIDE_SOURCE_FILE}" "${SAIL_BOOTSTRAP_WEB_OVERRIDE_SRC_CLIENT_DIR}/index.tsx"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/index.html" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/index.html"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/properties.json" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/properties.json"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/static/appd.v2.json" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/static/appd.v2.json"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/static/icon.svg" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/static/icon.svg"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/src/main.tsx" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/src/main.tsx"
cp "${SAIL_TRADERX_INTENT_LAUNCHER_SOURCE_DIR}/src/main.module.css" "${SAIL_BOOTSTRAP_TRADERX_INTENT_LAUNCHER_OVERRIDE_DIR}/src/main.module.css"

cat > "${SAIL_APPD_DIR}/traderx.appd.v2.json" <<'EOF'
{
  "message": "OK",
  "applications": [
    {
      "appId": "traderx-web",
      "name": "TraderX",
      "title": "TraderX",
      "description": "TraderX UI for blotters and ticket workflows",
      "type": "web",
      "details": {
        "url": "__TRADERX_URL__/trade"
      },
      "hostManifests": {
        "sail": {
          "injectApi": "2.0"
        }
      },
      "version": "0.1.0",
      "publisher": "FINOS",
      "icons": [
        {
          "src": "https://finos.org/wp-content/uploads/2018/03/finos-icon.svg"
        }
      ],
      "interop": {
        "intents": {
          "listensFor": {
            "ViewOrders": {
              "displayName": "View Orders",
              "contexts": [
                "fdc3.instrument"
              ]
            },
            "TraderX.CreateTradeTicket": {
              "displayName": "Create Trade Ticket",
              "contexts": [
                "fdc3.instrument"
              ]
            },
            "TraderX.CreateOrderTicket": {
              "displayName": "Create Order Ticket",
              "contexts": [
                "fdc3.instrument"
              ]
            }
          },
          "raises": {
            "ViewChart": {
              "displayName": "View Chart",
              "contexts": [
                "fdc3.instrument"
              ]
            },
            "ViewQuote": {
              "displayName": "View Quote",
              "contexts": [
                "fdc3.instrument"
              ]
            }
          }
        }
      }
    }
  ]
}
EOF

if [[ -d "${FRONTEND_OVERRIDE_SOURCE_DIR}" ]]; then
  cp -R "${FRONTEND_OVERRIDE_SOURCE_DIR}/." "${TARGET_FRONTEND_DIR}/"
else
  echo "[fail] frontend override source not found: ${FRONTEND_OVERRIDE_SOURCE_DIR}"
  exit 1
fi

# Ensure state-014 FDC3 agent bootstrap dependency is present in generated web UI.
node - "${TARGET_FRONTEND_DIR}/package.json" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const doc = JSON.parse(fs.readFileSync(path, 'utf8'));
doc.dependencies = doc.dependencies || {};
if (!doc.dependencies['@robmoffat/fdc3-get-agent']) {
  doc.dependencies['@robmoffat/fdc3-get-agent'] = '2.2.2-beta.3';
}
fs.writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
NODE

chmod +x \
  "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" \
  "${SAIL_BOOTSTRAP_DIR}/apply-tradingview-overrides.sh" \
  "${SAIL_BOOTSTRAP_DIR}/merge-traderx-appd.sh"

echo "[done] rendered state 014 Sail artifacts into ${STATE_DIR}"
