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
SAIL_APPD_DIR="${SAIL_DIR}/appd"
SAIL_CACHE_DIR="${SAIL_DIR}/runtime-cache"
SAIL_PIN_FILE="${STATE_SPEC_DIR}/generation/sail-pin.env"
FRONTEND_OVERRIDE_SOURCE_DIR="${STATE_SPEC_DIR}/generation/frontend-overrides/web-front-end/angular"
TARGET_FRONTEND_DIR="${TARGET_ROOT}/web-front-end/angular"
UPSTREAM_BUILD_PLAN="${UPSTREAM_DIR}/upstream-build-plan.json"

for required in "${UPSTREAM_DIR}/README.md" "${UPSTREAM_DIR}/tilt/Tiltfile"; do
  [[ -e "${required}" ]] || {
    echo "[fail] required state 012 artifact missing for state 014 render: ${required}"
    exit 1
  }
done

[[ -f "${SAIL_PIN_FILE}" ]] || {
  echo "[fail] missing Sail pin manifest: ${SAIL_PIN_FILE}"
  exit 1
}
# shellcheck disable=SC1090
source "${SAIL_PIN_FILE}"
for required_var in SAIL_PIN_REPO_URL SAIL_PIN_TRACKING_REF SAIL_PINNED_REF SAIL_PIN_UPDATED_ON; do
  [[ -n "${!required_var:-}" ]] || {
    echo "[fail] ${SAIL_PIN_FILE} missing ${required_var}"
    exit 1
  }
done
if ! [[ "${SAIL_PINNED_REF}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "[fail] SAIL_PINNED_REF must be a 40-char git commit SHA in ${SAIL_PIN_FILE}"
  exit 1
fi

rm -rf "${STATE_DIR}"
mkdir -p \
  "${SAIL_BOOTSTRAP_DIR}" \
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
- TraderX app directory overlay: `sail/appd/traderx.appd.v2.json`
- Sail runtime cache root: `sail/runtime-cache/`

Pinned Sail source defaults are defined in:

- `sail/bootstrap/sail-pin.env`

Run baseline C3 runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind
```

Run C3 + Sail demo runtime:

```bash
./scripts/start-state-014-fdc3-intent-interoperability-generated.sh --provider kind --with-sail
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
- TradingView exchange/symbol compatibility remains Sail-side patchwork for demo parity.
- TraderX may use a bounded active-channel context-sync fallback to compensate for inconsistent demo-agent callback delivery; remove when robust Sail event delivery is available.

Maintenance checks:

```bash
# verify pin manifest contract
bash pipeline/validate-sail-pin-contract.sh

# detect upstream Sail drift vs pinned commit
bash pipeline/check-sail-pin-drift.sh --fail-on-drift
```
EOF

cat > "${SAIL_DIR}/docker-compose.yml" <<EOF
name: traderx-state-014-sail

services:
  sail:
    image: node:20-bookworm
    working_dir: /workspace/runtime-cache
    restart: unless-stopped
    environment:
      SAIL_REPO_URL: "\${SAIL_REPO_URL:-${SAIL_PIN_REPO_URL}}"
      SAIL_REPO_REF: "\${SAIL_REPO_REF:-${SAIL_PINNED_REF}}"
      SAIL_TRADERX_URL: "\${SAIL_TRADERX_URL:-http://localhost:8080}"
      SAIL_HTTP_PORT: "\${SAIL_HTTP_PORT:-8090}"
      SAIL_EXAMPLE_PORT_RANGE_START: "\${SAIL_EXAMPLE_PORT_RANGE_START:-4010}"
      SAIL_EXAMPLE_PORT_RANGE_END: "\${SAIL_EXAMPLE_PORT_RANGE_END:-4065}"
    command: ["/bin/bash", "/workspace/bootstrap/run-sail.sh"]
    volumes:
      - ./runtime-cache:/workspace/runtime-cache
      - ./bootstrap:/workspace/bootstrap:ro
      - ./appd:/workspace/appd:ro
    ports:
      - "\${SAIL_HTTP_PORT:-8090}:8090"
      - "\${SAIL_EXAMPLE_PORT_RANGE_START:-4010}-\${SAIL_EXAMPLE_PORT_RANGE_END:-4065}:4010-4065"
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PIN_FILE="${SAIL_PIN_FILE:-/workspace/bootstrap/sail-pin.env}"
SAIL_PIN_REPO_URL_DEFAULT="https://github.com/finos/FDC3-Sail.git"
SAIL_PIN_TRACKING_REF_DEFAULT="main"
SAIL_PINNED_REF_DEFAULT="main"

if [[ -f "${PIN_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${PIN_FILE}"
fi

SAIL_REPO_URL="${SAIL_REPO_URL:-${SAIL_PIN_REPO_URL:-${SAIL_PIN_REPO_URL_DEFAULT}}}"
SAIL_REPO_REF="${SAIL_REPO_REF:-${SAIL_PINNED_REF:-${SAIL_PINNED_REF_DEFAULT}}}"
SAIL_REPO_TRACKING_REF="${SAIL_REPO_TRACKING_REF:-${SAIL_PIN_TRACKING_REF:-${SAIL_PIN_TRACKING_REF_DEFAULT}}}"
SAIL_REPO_DIR="${SAIL_REPO_DIR:-/workspace/runtime-cache/FDC3-Sail}"
SAIL_TRADERX_URL="${SAIL_TRADERX_URL:-http://localhost:8080}"
SAIL_APPD_BASE="${SAIL_REPO_DIR}/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"
SAIL_TRADERX_APPD="/workspace/appd/traderx.appd.v2.json"

mkdir -p "$(dirname "${SAIL_REPO_DIR}")"

if [[ ! -d "${SAIL_REPO_DIR}/.git" ]]; then
  echo "[info] cloning Sail repository (${SAIL_REPO_REF}; tracking=${SAIL_REPO_TRACKING_REF})"
  git clone --depth 1 "${SAIL_REPO_URL}" "${SAIL_REPO_DIR}"
  git -C "${SAIL_REPO_DIR}" remote set-url origin "${SAIL_REPO_URL}"
  if [[ "${SAIL_REPO_REF}" =~ ^[0-9a-f]{40}$ ]]; then
    git -C "${SAIL_REPO_DIR}" fetch --depth 1 origin "${SAIL_REPO_REF}"
    git -C "${SAIL_REPO_DIR}" checkout --force FETCH_HEAD
  else
    git -C "${SAIL_REPO_DIR}" fetch --depth 1 origin "${SAIL_REPO_REF}"
    git -C "${SAIL_REPO_DIR}" checkout --force FETCH_HEAD
  fi
else
  echo "[info] updating Sail repository (${SAIL_REPO_REF}; tracking=${SAIL_REPO_TRACKING_REF})"
  git -C "${SAIL_REPO_DIR}" remote set-url origin "${SAIL_REPO_URL}"
  git -C "${SAIL_REPO_DIR}" fetch --depth 1 origin "${SAIL_REPO_REF}"
  git -C "${SAIL_REPO_DIR}" checkout --force FETCH_HEAD
fi

cd "${SAIL_REPO_DIR}"

echo "[info] installing Sail dependencies"
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

cp "${SAIL_PIN_FILE}" "${SAIL_BOOTSTRAP_DIR}/sail-pin.env"

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

# Ensure state-014 web UI includes primary + compatibility getAgent implementations.
node - "${TARGET_FRONTEND_DIR}/package.json" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const doc = JSON.parse(fs.readFileSync(path, 'utf8'));
doc.dependencies = doc.dependencies || {};
doc.dependencies['@morgan-stanley/fdc3-web'] = '^0.11.2';
doc.dependencies['@robmoffat/fdc3-get-agent'] = '^2.2.2-beta.3';
fs.writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
NODE

chmod +x \
  "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" \
  "${SAIL_BOOTSTRAP_DIR}/merge-traderx-appd.sh"

echo "[done] rendered state 014 Sail artifacts into ${STATE_DIR}"
