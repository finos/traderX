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
- Sail v3 bootstrap patcher: `sail/bootstrap/apply-sail-demo-compat.sh`
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

Demo script:

1. Open Sail at `http://localhost:8090/` and verify the Sail v3 workspace loads:
2. Confirm the TraderX, TraderX Intent Launcher, FDC3 toolbox TradingView/Pricer, and FINOS conformance app directory entries are available in the Sail app directory.
3. Launch TraderX from Sail and verify it connects with `@finos/fdc3@3.0.0-alpha.2` `getAgent()`.
4. Launch Trading View Chart or Pricer from Sail and verify the toolbox app is framed in the Sail workspace.
5. Change selected ticker in TraderX blotters and verify Sail-hosted apps update via `fdc3.instrument` context or intent routing.

Known demo workarounds / technical debt:

- TraderX publishes canonical bare ticker payloads only (`fdc3.instrument.id.ticker`).
- TraderX may use a bounded active-channel context-sync fallback to compensate for inconsistent demo-agent callback delivery; remove when robust Sail event delivery is available.
EOF

cat > "${SAIL_DIR}/docker-compose.yml" <<'EOF'
name: traderx-state-014-sail

services:
  sail:
    image: node:24-bookworm
    working_dir: /workspace/runtime-cache
    restart: unless-stopped
    environment:
      SAIL_REPO_URL: "${SAIL_REPO_URL:-https://github.com/DovOps/FDC3-Sail.git}"
      SAIL_REPO_REF: "${SAIL_REPO_REF:-codex/state014-demo-runtime}"
      SAIL_REPO_COMMIT: "${SAIL_REPO_COMMIT:-}"
      SAIL_TRADERX_URL: "${SAIL_TRADERX_URL:-http://localhost:8080}"
      VITE_SAIL_APP_DIRECTORY_URLS: "${VITE_SAIL_APP_DIRECTORY_URLS:-http://localhost:8080/fdc3/appd/v2/apps,http://localhost:4005/static/generated/fdc3-example-apps.json}"
      SAIL_HTTP_PORT: "${SAIL_HTTP_PORT:-8090}"
      SAIL_INTENT_LAUNCHER_URL: "${SAIL_INTENT_LAUNCHER_URL:-http://localhost:4040}"
      SAIL_TRADINGVIEW_URL: "${SAIL_TRADINGVIEW_URL:-http://localhost:4023}"
      SAIL_PRICER_URL: "${SAIL_PRICER_URL:-http://localhost:4020}"
      SAIL_EXAMPLE_APPD_URL: "${SAIL_EXAMPLE_APPD_URL:-http://localhost:4005/static/generated/fdc3-example-apps.json}"
      SAIL_FDC3_EXAMPLE_APPS_VERSION: "${SAIL_FDC3_EXAMPLE_APPS_VERSION:-3.0.0-alpha.2}"
      SAIL_EXAMPLE_PORT_RANGE_START: "${SAIL_EXAMPLE_PORT_RANGE_START:-4005}"
      SAIL_EXAMPLE_PORT_RANGE_END: "${SAIL_EXAMPLE_PORT_RANGE_END:-4065}"
    command: ["/bin/bash", "/workspace/bootstrap/run-sail.sh"]
    volumes:
      - ./runtime-cache:/workspace/runtime-cache
      - ./bootstrap:/workspace/bootstrap:ro
      - ./appd:/workspace/appd:ro
    ports:
      - "${SAIL_HTTP_PORT:-8090}:3000"
      - "${SAIL_EXAMPLE_PORT_RANGE_START:-4005}-${SAIL_EXAMPLE_PORT_RANGE_END:-4065}:4005-4065"
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAIL_PIN_FILE="${SAIL_PIN_FILE:-/workspace/bootstrap/sail-pin.env}"
if [[ -f "${SAIL_PIN_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${SAIL_PIN_FILE}"
fi

SAIL_REPO_URL="${SAIL_REPO_URL:-${SAIL_PIN_REPO_URL:-https://github.com/DovOps/FDC3-Sail.git}}"
SAIL_REPO_REF="${SAIL_REPO_REF:-${SAIL_PIN_REPO_REF:-${SAIL_PINNED_REF:-${SAIL_PIN_TRACKING_REF:-main}}}}"
SAIL_REPO_REF="${SAIL_REPO_REF#origin/}"
SAIL_REPO_COMMIT="${SAIL_REPO_COMMIT:-${SAIL_PIN_REPO_COMMIT:-${SAIL_PINNED_REF:-}}}"
SAIL_REPO_DIR="${SAIL_REPO_DIR:-/workspace/runtime-cache/FDC3-Sail}"
SAIL_TRADERX_URL="${SAIL_TRADERX_URL:-http://localhost:8080}"
SAIL_EXAMPLE_APPD_URL="${SAIL_EXAMPLE_APPD_URL:-http://localhost:4005/static/generated/fdc3-example-apps.json}"
SAIL_FDC3_EXAMPLE_APPS_VERSION="${SAIL_FDC3_EXAMPLE_APPS_VERSION:-3.0.0-alpha.2}"
export VITE_SAIL_APP_DIRECTORY_URLS="${VITE_SAIL_APP_DIRECTORY_URLS:-${SAIL_TRADERX_URL%/}/fdc3/appd/v2/apps,${SAIL_EXAMPLE_APPD_URL}}"
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

if [[ -x /workspace/bootstrap/apply-sail-demo-compat.sh ]]; then
  echo "[info] applying state-014 Sail overrides"
  /workspace/bootstrap/apply-sail-demo-compat.sh "${SAIL_REPO_DIR}"
fi

echo "[info] installing Sail dependencies"
rm -rf node_modules
npm install --no-audit --no-fund
npm --prefix "${SAIL_REPO_DIR}/packages/traderx-sail-intent-launcher" install --no-audit --no-fund

echo "[start] launching TraderX intent launcher"
npm --prefix "${SAIL_REPO_DIR}/packages/traderx-sail-intent-launcher" run dev -- --host 0.0.0.0 &
LAUNCHER_PID=$!

echo "[start] launching FDC3 toolbox example apps"
npx --yes "@finos/fdc3-example-apps@${SAIL_FDC3_EXAMPLE_APPS_VERSION}" &
EXAMPLE_APPS_PID=$!

echo "[start] launching Sail v3 browser desktop agent"
npm run dev &
WEB_PID=$!

cleanup() {
  kill "${LAUNCHER_PID}" >/dev/null 2>&1 || true
  kill "${EXAMPLE_APPS_PID}" >/dev/null 2>&1 || true
  kill "${WEB_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

set +e
wait -n "${LAUNCHER_PID}" "${EXAMPLE_APPS_PID}" "${WEB_PID}"
status="$?"
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[error] Sail process exited unexpectedly (status=${status})"
fi
exit "${status}"
EOF

cat > "${SAIL_BOOTSTRAP_DIR}/apply-sail-demo-compat.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SAIL_REPO_DIR="${1:-/workspace/runtime-cache/FDC3-Sail}"
TRADERX_APPD="/workspace/appd/traderx.appd.v2.json"
TARGET_TRADERX_APPD="${SAIL_REPO_DIR}/packages/sail-web/fixtures/traderx-appd.json"
SAIL_WEB_MAIN="${SAIL_REPO_DIR}/packages/sail-web/src/main.tsx"
SAIL_WEB_VITE_CONFIG="${SAIL_REPO_DIR}/packages/sail-web/vite.config.ts"
SAIL_INTENT_LAUNCHER_DIR="${SAIL_REPO_DIR}/packages/traderx-sail-intent-launcher"
SAIL_INTENT_LAUNCHER_URL="${SAIL_INTENT_LAUNCHER_URL:-http://localhost:4040}"

mkdir -p "${SAIL_INTENT_LAUNCHER_DIR}/src" "${SAIL_INTENT_LAUNCHER_DIR}/public"
cat > "${SAIL_INTENT_LAUNCHER_DIR}/package.json" <<'JSON'
{
  "name": "@traderx/sail-intent-launcher",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --port 4040",
    "build": "vite build"
  },
  "dependencies": {
    "@finos/fdc3": "3.0.0-alpha.2",
    "@vitejs/plugin-react": "^5.1.3",
    "vite": "^7.3.0",
    "typescript": "^5.9.3",
    "react": "^19.2.3",
    "react-dom": "^19.2.3"
  },
  "devDependencies": {
    "@types/react": "^19.2.7",
    "@types/react-dom": "^19.2.3"
  }
}
JSON
cat > "${SAIL_INTENT_LAUNCHER_DIR}/index.html" <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <title>TraderX Intent Launcher</title>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <script type="module" src="/src/main.tsx"></script>
  </head>
  <body>
    <div id="app">Loading TraderX intent launcher...</div>
  </body>
</html>
HTML
cat > "${SAIL_INTENT_LAUNCHER_DIR}/src/main.tsx" <<'TSX'
import React, { useEffect, useRef, useState } from "react"
import { createRoot } from "react-dom/client"
import { getAgent, type DesktopAgent } from "@finos/fdc3"
import styles from "./main.module.css"

type InstrumentContext = {
  type: "fdc3.instrument"
  id: {
    ticker: string
  }
}

type ListenerLike = {
  unsubscribe?: () => void
}

type UserChannelLike = {
  id?: string
  getCurrentContext?: (contextType?: string) => Promise<unknown> | unknown
}

const ensureUserChannel = async (agent: DesktopAgent): Promise<UserChannelLike | null> => {
  const channelAgent = agent as DesktopAgent & {
    getCurrentChannel?: () => Promise<UserChannelLike | null> | UserChannelLike | null
    getUserChannels?: () => Promise<UserChannelLike[]> | UserChannelLike[]
    joinUserChannel?: (channelId: string) => Promise<void> | void
  }
  if (!channelAgent.getCurrentChannel || !channelAgent.getUserChannels || !channelAgent.joinUserChannel) {
    return null
  }
  const current = await Promise.resolve(channelAgent.getCurrentChannel())
  if (current?.id) return current
  const channels = await Promise.resolve(channelAgent.getUserChannels())
  const defaultChannel = Array.isArray(channels) ? channels[0] : undefined
  if (!defaultChannel?.id) return null
  await Promise.resolve(channelAgent.joinUserChannel(defaultChannel.id))
  return (await Promise.resolve(channelAgent.getCurrentChannel())) ?? defaultChannel
}

const extractTicker = (context: unknown) => {
  const candidate = context as { type?: unknown; id?: { ticker?: unknown } } | null | undefined
  if (candidate?.type !== "fdc3.instrument" || typeof candidate.id?.ticker !== "string") {
    return null
  }
  const normalized = candidate.id.ticker.trim().toUpperCase()
  return normalized.length > 0 ? normalized : null
}

const createInstrumentContext = (ticker: string): InstrumentContext => ({
  type: "fdc3.instrument",
  id: { ticker },
})

function TraderXIntentLauncher() {
  const agentRef = useRef<DesktopAgent | null>(null)
  const listenersRef = useRef<ListenerLike[]>([])
  const [currentChannelId, setCurrentChannelId] = useState("(none)")
  const [ticker, setTicker] = useState<string | null>(null)
  const [pendingIntent, setPendingIntent] = useState<string | null>(null)
  const [status, setStatus] = useState("Connecting to Sail...")

  const syncCurrentContext = async (agent: DesktopAgent) => {
    const currentChannel = await ensureUserChannel(agent)
    setCurrentChannelId(currentChannel?.id ?? "(none)")
    const context =
      (await currentChannel?.getCurrentContext?.("fdc3.instrument")) ??
      (await agent.getCurrentContext?.("fdc3.instrument"))
    setTicker(extractTicker(context))
  }

  useEffect(() => {
    let isMounted = true

    const connect = async () => {
      try {
        const agent = await getAgent()
        if (!isMounted) return
        agentRef.current = agent
        await syncCurrentContext(agent)
        setStatus("Connected to Sail")

        const contextListener = await agent.addContextListener("fdc3.instrument", context => {
          const receivedTicker = extractTicker(context)
          setTicker(receivedTicker)
          setStatus(`Received instrument context${receivedTicker ? ` (${receivedTicker})` : ""}`)
        })
        listenersRef.current.push(contextListener)

        const channelListener = await agent.addEventListener?.("userChannelChanged", () => {
          syncCurrentContext(agent).catch(error => {
            console.warn("[traderx-intent-launcher] channel sync failed", error)
          })
        })
        if (channelListener) {
          listenersRef.current.push(channelListener)
        }
      } catch (error) {
        console.error("[traderx-intent-launcher] failed to connect", error)
        setStatus(error instanceof Error ? error.message : "Failed to connect to Sail")
      }
    }

    void connect()

    return () => {
      isMounted = false
      listenersRef.current.forEach(listener => listener.unsubscribe?.())
      listenersRef.current = []
    }
  }, [])

  const raiseTicketIntent = async (
    intent: "TraderX.CreateTradeTicket" | "TraderX.CreateOrderTicket",
  ) => {
    if (!agentRef.current || !ticker) return
    setPendingIntent(intent)
    setStatus(`Raising ${intent}`)
    try {
      const resolution = await agentRef.current.raiseIntent(intent, createInstrumentContext(ticker))
      await resolution?.getResult?.()
      setStatus(`${intent} raised for ${ticker}`)
    } catch (error) {
      console.error("[traderx-intent-launcher] raiseIntent failed", error)
      setStatus(error instanceof Error ? error.message : `Failed to raise ${intent}`)
    } finally {
      setPendingIntent(null)
    }
  }

  const controlsDisabled = !ticker || pendingIntent !== null || !agentRef.current

  return (
    <div className={styles.launcher}>
      <h2 className={styles.title}>TraderX Intent Launcher</h2>
      <p className={styles.metaLine}>
        <strong>Channel:</strong> {currentChannelId}
        <span className={styles.separator}>|</span>
        <strong>Ticker:</strong>{" "}
        <span className={styles.ticker}>{ticker ?? "No instrument selected"}</span>
      </p>
      <div className={styles.buttonRow}>
        <button
          type="button"
          className={`${styles.button} ${styles.trade}`}
          disabled={controlsDisabled}
          onClick={() => void raiseTicketIntent("TraderX.CreateTradeTicket")}
        >
          Create Trade Ticket
        </button>
        <button
          type="button"
          className={`${styles.button} ${styles.order}`}
          disabled={controlsDisabled}
          onClick={() => void raiseTicketIntent("TraderX.CreateOrderTicket")}
        >
          Create Order Ticket
        </button>
      </div>
      <p className={styles.status}>{status}</p>
    </div>
  )
}

const container = document.getElementById("app")
if (!container) {
  throw new Error("Missing #app container")
}

createRoot(container).render(<TraderXIntentLauncher />)
TSX
cat > "${SAIL_INTENT_LAUNCHER_DIR}/src/main.module.css" <<'CSS'
.launcher {
  min-height: 100vh;
  font-family: Inter, "Segoe UI", Arial, sans-serif;
  color: #dbeafe;
  background: #07111f;
  padding: 18px;
}

.title {
  margin: 0 0 10px;
  font-size: 1.1rem;
}

.metaLine,
.status {
  margin: 0 0 12px;
  color: #9fb3c8;
  font-size: 0.9rem;
}

.separator {
  margin: 0 8px;
  color: #64748b;
}

.ticker {
  color: #67e8f9;
  font-weight: 700;
}

.buttonRow {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.button {
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 6px;
  padding: 9px 12px;
  color: #fff;
  font-size: 0.9rem;
  font-weight: 650;
  cursor: pointer;
}

.trade {
  background: #0ea5e9;
}

.order {
  background: #16a34a;
}

.button:disabled {
  cursor: not-allowed;
  opacity: 0.45;
}
CSS
cat > "${SAIL_INTENT_LAUNCHER_DIR}/public/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <rect width="96" height="96" rx="18" fill="#07111f"/>
  <path d="M23 30h50M23 48h50M23 66h30" stroke="#67e8f9" stroke-width="8" stroke-linecap="round"/>
  <circle cx="70" cy="66" r="10" fill="#22c55e"/>
</svg>
SVG

node - "${SAIL_REPO_DIR}" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
const alphaVersion = '3.0.0-alpha.2';
const rootPackageFile = path.join(root, 'package.json');
const rootPackage = JSON.parse(fs.readFileSync(rootPackageFile, 'utf8'));
rootPackage.workspaces = Array.isArray(rootPackage.workspaces) ? rootPackage.workspaces : [];
if (!rootPackage.workspaces.includes('packages/traderx-sail-intent-launcher')) {
  rootPackage.workspaces.push('packages/traderx-sail-intent-launcher');
}
fs.writeFileSync(rootPackageFile, `${JSON.stringify(rootPackage, null, 2)}\n`, 'utf8');

const packageFiles = [
  'package.json',
  'packages/sail-web/package.json',
  'packages/sail-electron/package.json',
  'packages/sail-desktop-agent/package.json',
  'packages/sail-platform-api/package.json',
  'packages/sail-conformance-harness/package.json',
  'packages/traderx-sail-intent-launcher/package.json'
].map((file) => path.join(root, file)).filter((file) => fs.existsSync(file));

for (const packageFile of packageFiles) {
  const doc = JSON.parse(fs.readFileSync(packageFile, 'utf8'));
  for (const section of ['dependencies', 'devDependencies', 'peerDependencies', 'overrides']) {
    if (!doc[section] || typeof doc[section] !== 'object' || Array.isArray(doc[section])) {
      continue;
    }
    if (doc[section]['@finos/fdc3']) {
      doc[section]['@finos/fdc3'] = alphaVersion;
    }
    if (doc[section]['@finos/fdc3-schema']) {
      doc[section]['@finos/fdc3-schema'] = alphaVersion;
    }
  }
  doc.overrides = doc.overrides || {};
  doc.overrides['@finos/fdc3'] = alphaVersion;
  doc.overrides['@finos/fdc3-schema'] = alphaVersion;
  fs.writeFileSync(packageFile, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
}
NODE
echo "[ok] aligned Sail workspace FDC3 packages to 3.0.0-alpha.2"

mkdir -p "$(dirname "${TARGET_TRADERX_APPD}")"
cp "${TRADERX_APPD}" "${TARGET_TRADERX_APPD}"
node - "${TARGET_TRADERX_APPD}" "${SAIL_REPO_DIR}" <<'NODE'
const fs = require('node:fs');
const appdPath = process.argv[2];
const repoDir = process.argv[3];
const traderxUrl = process.env.SAIL_TRADERX_URL || 'http://localhost:8080';
const launcherUrl = process.env.SAIL_INTENT_LAUNCHER_URL || 'http://localhost:4040';
const traderxTradeUrl = `${traderxUrl.replace(/\/+$/, '')}/trade`;
const traderxMiniUrl = `${traderxUrl.replace(/\/+$/, '')}/mini-traderx`;
const doc = JSON.parse(fs.readFileSync(appdPath, 'utf8'));
const appsById = new Map((doc.applications || []).map((app) => [app.appId, app]));
appsById.set('traderx-web', {
  ...appsById.get('traderx-web'),
  details: {
    ...((appsById.get('traderx-web') || {}).details || {}),
    url: traderxTradeUrl,
  },
  interop: {
    ...((appsById.get('traderx-web') || {}).interop || {}),
    userChannels: {
      broadcasts: ['fdc3.instrument', 'traderx.account'],
      listensFor: ['fdc3.instrument', 'traderx.account'],
    },
  },
});
appsById.set('traderx-mini', {
  appId: 'traderx-mini',
  name: 'Mini TraderX',
  title: 'Mini TraderX',
  description: 'Compact TraderX companion view for account and instrument-scoped live positions.',
  type: 'web',
  details: {
    url: traderxMiniUrl,
  },
  hostManifests: {},
  version: '0.1.0',
  publisher: 'FINOS',
  icons: [
    {
      src: 'https://finos.org/wp-content/uploads/2018/03/finos-icon.svg',
    },
  ],
  interop: {
    intents: {
      listensFor: {},
      raises: {},
    },
    userChannels: {
      broadcasts: ['fdc3.instrument', 'traderx.account'],
      listensFor: ['fdc3.instrument', 'traderx.account'],
    },
  },
});
appsById.set('traderx-intent-launcher', {
  appId: 'traderx-intent-launcher',
  name: 'TraderX Intent Launcher',
  title: 'TraderX Intent Launcher',
  description: 'Raises TraderX trade/order ticket intents for the current fdc3.instrument ticker',
  type: 'web',
  details: {
    url: `${launcherUrl.replace(/\/+$/, '')}/`,
  },
  hostManifests: {},
  version: '0.1.0',
  publisher: 'FINOS',
  icons: [
    {
      src: `${launcherUrl.replace(/\/+$/, '')}/icon.svg`,
    },
  ],
  interop: {
    intents: {
      raises: {
        'TraderX.CreateTradeTicket': {
          displayName: 'Create Trade Ticket',
          contexts: ['fdc3.instrument'],
        },
        'TraderX.CreateOrderTicket': {
          displayName: 'Create Order Ticket',
          contexts: ['fdc3.instrument'],
        },
      },
    },
    userChannels: {
      broadcasts: [],
      listensFor: ['fdc3.instrument'],
    },
  },
});
doc.applications = Array.from(appsById.values()).map((app) => {
  if (app.appId !== 'traderx-web') {
    return app;
  }
	  return {
	    ...app,
	    details: {
	      ...(app.details || {}),
	      url: traderxTradeUrl,
	    },
	    interop: {
	      ...(app.interop || {}),
	      userChannels: {
	        broadcasts: ['fdc3.instrument', 'traderx.account'],
	        listensFor: ['fdc3.instrument', 'traderx.account'],
	      },
	    },
	  };
	});
fs.writeFileSync(appdPath, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');

const mainPath = `${repoDir}/packages/sail-web/src/main.tsx`;
let main = fs.readFileSync(mainPath, 'utf8');
if (!main.includes('traderxAppDirectory')) {
  main = main.replace(
    'import defaultAppDirectory from "../fixtures/default-app-directory.json"',
    'import defaultAppDirectory from "../fixtures/default-app-directory.json"\nimport traderxAppDirectory from "../fixtures/traderx-appd.json"'
  );
}
if (!main.includes('conformanceAppDirectory')) {
  main = main.replace(
    'import traderxAppDirectory from "../fixtures/traderx-appd.json"',
    'import conformanceAppDirectory from "../../sail-conformance-harness/conformance-appd.json"\nimport traderxAppDirectory from "../fixtures/traderx-appd.json"'
  );
}
main = main
  .replace('import defaultAppDirectory from "../fixtures/default-app-directory.json"\n', '')
  .replace(
    /    apps: \[[\s\S]*?\] as unknown as DirectoryApp\[\],/,
    '    apps: [\n      ...traderxAppDirectory.applications,\n      ...conformanceAppDirectory.applications,\n    ] as unknown as DirectoryApp[],'
  );
fs.writeFileSync(mainPath, main, 'utf8');
NODE
echo "[ok] configured TraderX launcher and conformance AppD fixtures in Sail web startup"

SAIL_WEB_CHANNEL_SELECTOR="${SAIL_REPO_DIR}/packages/sail-web/src/components/ChannelSelector.tsx"
if [[ -f "${SAIL_WEB_CHANNEL_SELECTOR}" ]] && grep -q 'useStore(storeApi' "${SAIL_WEB_CHANNEL_SELECTOR}"; then
  node - "${SAIL_WEB_CHANNEL_SELECTOR}" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');
source = source
  .replace('import { useStore, type StoreApi } from "zustand"\n', '')
  .replace('import type { ConnectionStore } from "../stores/connection-store"\n', '')
  .replace(
    [
      '  const connectionStore = useConnectionStore()',
      '  const storeApi = connectionStore as unknown as StoreApi<ConnectionStore>',
      '  // Subscribe to connection-store push updates (channelChanged) — not agent state snapshots.',
      '  const connection = useStore(storeApi, state => state.getConnection(instanceId))',
    ].join('\n'),
    [
      '  const connectionStore = useConnectionStore()',
      '  const connection = connectionStore.getConnection(instanceId)',
    ].join('\n')
  );
fs.writeFileSync(path, source, 'utf8');
NODE
  echo "[ok] patched Sail v3 ChannelSelector Zustand hook usage"
fi

SAIL_WEB_WORKSPACE_STORE="${SAIL_REPO_DIR}/packages/sail-web/src/stores/workspace-store.ts"
if [[ -f "${SAIL_WEB_WORKSPACE_STORE}" ]] && ! grep -q 'TRADERX_DEMO_WORKSPACE_ID' "${SAIL_WEB_WORKSPACE_STORE}"; then
  node - "${SAIL_WEB_WORKSPACE_STORE}" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');
const demoBlock = `const TRADERX_DEMO_WORKSPACE_ID = "traderx-fdc3-demo-workspace"
const TRADERX_DEMO_TAB_ID = "traderx-fdc3-demo-main"

const createTraderXDemoWorkspace = (): Workspace => {
  const panels = new Map<string, Panel>(
    [
      {
        panelId: "traderx-web-demo",
        appId: "traderx-web",
        title: "TraderX",
        url: "http://localhost:8080/trade",
        icon: null,
      },
      {
        panelId: "traderx-mini-demo",
        appId: "traderx-mini",
        title: "Mini TraderX",
        url: "http://localhost:8080/mini-traderx",
        icon: null,
      },
      {
        panelId: "trading-view-symbol-info-demo",
        appId: "trading-view-symbol-info-1",
        title: "Trading View Symbol Info",
        url: "http://localhost:4023/?mode=symbol-info",
        icon: "http://localhost:4023/tradingview-icon.png",
      },
      {
        panelId: "traderx-intent-launcher-demo",
        appId: "traderx-intent-launcher",
        title: "TraderX Intent Launcher",
        url: "http://localhost:4040/",
        icon: "http://localhost:4040/icon.svg",
      },
      {
        panelId: "trading-view-chart-demo",
        appId: "trading-view-chart-1",
        title: "Trading View Chart",
        url: "http://localhost:4023/?mode=chart",
        icon: "http://localhost:4023/tradingview-icon.png",
      },
      {
        panelId: "trading-view-fundamentals-demo",
        appId: "trading-view-fundamentals-1",
        title: "Trading View Fundamentals",
        url: "http://localhost:4023/?mode=fundamentals",
        icon: "http://localhost:4023/tradingview-icon.png",
      },
    ].map(panel => [panel.panelId, panel])
  )

  const dockviewLayout = {
    grid: {
      root: {
        type: "branch",
        data: [
          {
            type: "leaf",
            data: {
              views: ["traderx-web-demo"],
              activeView: "traderx-web-demo",
              id: "1",
            },
            size: 1134.189208984375,
          },
          {
            type: "branch",
            data: [
              {
                type: "leaf",
                data: {
                  views: ["traderx-mini-demo"],
                  activeView: "traderx-mini-demo",
                  id: "3",
                },
                size: 386,
              },
              {
                type: "branch",
                data: [
                  {
                    type: "branch",
                    data: [
                      {
                        type: "leaf",
                        data: {
                          views: ["trading-view-symbol-info-demo"],
                          activeView: "trading-view-symbol-info-demo",
                          id: "2",
                        },
                        size: 546,
                      },
                      {
                        type: "leaf",
                        data: {
                          views: ["traderx-intent-launcher-demo"],
                          activeView: "traderx-intent-launcher-demo",
                          id: "8",
                        },
                        size: 278,
                      },
                    ],
                    size: 453,
                  },
                  {
                    type: "leaf",
                    data: {
                      views: ["trading-view-chart-demo"],
                      activeView: "trading-view-chart-demo",
                      id: "4",
                    },
                    size: 453,
                  },
                  {
                    type: "leaf",
                    data: {
                      views: ["trading-view-fundamentals-demo"],
                      activeView: "trading-view-fundamentals-demo",
                      id: "7",
                    },
                    size: 453.138916015625,
                  },
                ],
                size: 824,
              },
            ],
            size: 1359.138916015625,
          },
        ],
        size: 1210,
      },
      width: 2493.328125,
      height: 1210,
      orientation: "HORIZONTAL",
    },
    panels: Object.fromEntries(
      Array.from(panels.values()).map(panel => [
        panel.panelId,
        {
          id: panel.panelId,
          contentComponent: "fdc3",
          tabComponent: "fdc3Tab",
          params: {
            panel: {
              ...panel,
              tabId: TRADERX_DEMO_TAB_ID,
            },
          },
          title: panel.title,
          renderer: "always",
        },
      ])
    ),
    activeGroup: "8",
  }

  return {
    uuid: TRADERX_DEMO_WORKSPACE_ID,
    name: "TraderX FDC3 Demo",
    timeLastSaved: Date.now(),
    layout: {
      tabs: new Map([
        [
          TRADERX_DEMO_TAB_ID,
          {
            tabId: TRADERX_DEMO_TAB_ID,
            name: "Main",
            panels,
          },
        ],
      ]),
      activeTabId: TRADERX_DEMO_TAB_ID,
      dockviewLayout,
    },
  }
}

const ensureTraderXDemoWorkspace = (workspaces: Map<string, Workspace>) => {
  const demoWorkspace = createTraderXDemoWorkspace()
  const existing = workspaces.get(TRADERX_DEMO_WORKSPACE_ID)
  if (!existing) {
    workspaces.set(TRADERX_DEMO_WORKSPACE_ID, demoWorkspace)
    return
  }

  existing.name = demoWorkspace.name
  existing.layout.activeTabId = TRADERX_DEMO_TAB_ID
  existing.layout.dockviewLayout = demoWorkspace.layout.dockviewLayout
  const tab = existing.layout.tabs.get(TRADERX_DEMO_TAB_ID) ?? {
    tabId: TRADERX_DEMO_TAB_ID,
    name: "Main",
    panels: new Map<string, Panel>(),
  }
  tab.name = "Main"
  for (const [panelId, panel] of demoWorkspace.layout.tabs.get(TRADERX_DEMO_TAB_ID)!.panels) {
    tab.panels.set(panelId, panel)
  }
  existing.layout.tabs.set(TRADERX_DEMO_TAB_ID, tab)
}
`;
source = source.replace('\n\n// Create default empty workspace\n', `\n\n${demoBlock}\n// Create default empty workspace\n`);
source = source.replace(
  /\/\/ Create default empty workspace\nconst createDefaultWorkspace = \(\): Workspace => \{[\s\S]*?\n\}\n\n\/\/ Custom storage implementation/,
  '// Create default empty workspace\nconst createDefaultWorkspace = (): Workspace => {\n  return createTraderXDemoWorkspace()\n}\n\n// Custom storage implementation'
);
source = source.replace(
  '      return deserializedState\n',
  '      ensureTraderXDemoWorkspace(deserializedState.state.workspaces)\n      deserializedState.state.activeWorkspaceId = TRADERX_DEMO_WORKSPACE_ID\n\n      return deserializedState\n'
);
source = source.replace(
  '          activeWorkspaceId: defaultWorkspace.uuid,\n',
  '          activeWorkspaceId: TRADERX_DEMO_WORKSPACE_ID,\n'
);
fs.writeFileSync(path, source, 'utf8');
NODE
  echo "[ok] seeded Sail web TraderX FDC3 demo workspace"
fi

SAIL_WEB_LAYOUT="${SAIL_REPO_DIR}/packages/sail-web/src/components/layout-grid/Layout.tsx"
if [[ -f "${SAIL_WEB_LAYOUT}" ]] && ! grep -q 'demoPanelPositions' "${SAIL_WEB_LAYOUT}"; then
  node - "${SAIL_WEB_LAYOUT}" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');
source = source.replace(
  [
    'const TabComponents = {',
    '  fdc3Tab: FDC3Tab,',
    '}',
  ].join('\n'),
  [
    'const TabComponents = {',
    '  fdc3Tab: FDC3Tab,',
    '}',
    '',
	    'const demoPanelPositions: Record<',
	    '  string,',
	    '  { referencePanel: string; direction: "right" | "below" }',
	    '> = {',
	    '  "traderx-mini-demo": { referencePanel: "traderx-web-demo", direction: "right" },',
	    '  "trading-view-symbol-info-demo": { referencePanel: "traderx-mini-demo", direction: "below" },',
	    '  "traderx-intent-launcher-demo": {',
	    '    referencePanel: "trading-view-symbol-info-demo",',
    '    direction: "below",',
    '  },',
	    '  "trading-view-chart-demo": { referencePanel: "traderx-intent-launcher-demo", direction: "right" },',
	    '  "trading-view-fundamentals-demo": {',
	    '    referencePanel: "trading-view-chart-demo",',
	    '    direction: "right",',
	    '  },',
    '}',
  ].join('\n')
);
source = source.replace(
  [
    '          api.current?.addPanel({',
    '            id: panel.panelId,',
    '            component: "fdc3",',
    '            tabComponent: "fdc3Tab",',
    '            title: panel.title,',
    '            params: { panel: fdc3Panel },',
    '            // Use \'always\' renderer to prevent iframe reload when panel is moved in DOM.',
    '            // According to dockview docs: "Re-parenting an iFrame will reload the contents',
    '            // of the iFrame or the rephrase this, moving an iFrame within the DOM will',
    '            // cause a reload of its contents." This prevents zombie instances caused by',
    '            // iframe reloads triggering disconnects/reconnects.',
    '            // See: https://dockview.dev/docs/advanced/iframe/',
    '            renderer: "always",',
    '          })',
  ].join('\n'),
  [
    '          const position = demoPanelPositions[panel.panelId]',
    '          const referencePanel = position ? api.current?.getPanel(position.referencePanel) : undefined',
    '          const addPanelOptions: Parameters<DockviewApi["addPanel"]>[0] = {',
    '            id: panel.panelId,',
    '            component: "fdc3",',
    '            tabComponent: "fdc3Tab",',
    '            title: panel.title,',
    '            params: { panel: fdc3Panel },',
    '            // Use \'always\' renderer to prevent iframe reload when panel is moved in DOM.',
    '            // According to dockview docs: "Re-parenting an iFrame will reload the contents',
    '            // of the iFrame or the rephrase this, moving an iFrame within the DOM will',
    '            // cause a reload of its contents." This prevents zombie instances caused by',
    '            // iframe reloads triggering disconnects/reconnects.',
    '            // See: https://dockview.dev/docs/advanced/iframe/',
    '            renderer: "always",',
    '          }',
    '          if (position && referencePanel) {',
    '            addPanelOptions.position = {',
    '              referencePanel,',
    '              direction: position.direction,',
    '            }',
    '          }',
    '',
    '          api.current?.addPanel(addPanelOptions)',
  ].join('\n')
);
fs.writeFileSync(path, source, 'utf8');
NODE
  echo "[ok] configured Sail web TraderX demo split layout placement"
fi

if [[ -f "${SAIL_WEB_VITE_CONFIG}" ]] && ! grep -q 'host: "0.0.0.0"' "${SAIL_WEB_VITE_CONFIG}"; then
  node - "${SAIL_WEB_VITE_CONFIG}" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
let source = fs.readFileSync(path, 'utf8');
source = source.replace('server: {\n    port: 3000,', 'server: {\n    host: "0.0.0.0",\n    port: 3000,');
source = source.replace('    open: true,', '    open: false,');
fs.writeFileSync(path, source, 'utf8');
NODE
  echo "[ok] configured Sail web dev server for container port publishing"
fi

if [[ -f "${SAIL_WEB_VITE_CONFIG}" ]] && ! grep -q '@finos/sail-desktop-agent/browser": path.resolve(__dirname, "../../packages/sail-desktop-agent/src/app-connection")' "${SAIL_WEB_VITE_CONFIG}"; then
  node - "${SAIL_WEB_VITE_CONFIG}" <<'NODE'
const fs = require('node:fs');
const configPath = process.argv[2];
let source = fs.readFileSync(configPath, 'utf8');
source = source.replace(
  '      "@finos/sail-ui": path.resolve(__dirname, "../../packages/sail-ui/src"),',
  [
    '      "@finos/sail-ui": path.resolve(__dirname, "../../packages/sail-ui/src"),',
    '      "@finos/sail-desktop-agent/browser": path.resolve(__dirname, "../../packages/sail-desktop-agent/src/app-connection"),',
    '      "@finos/sail-desktop-agent": path.resolve(__dirname, "../../packages/sail-desktop-agent/src"),',
    '      "@finos/sail-platform-api": path.resolve(__dirname, "../../packages/sail-platform-api/src"),',
  ].join('\n')
);
fs.writeFileSync(configPath, source, 'utf8');
NODE
  echo "[ok] configured Sail web Vite aliases for v3 workspace packages"
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
  "${SAIL_PIN_SOURCE_FILE}"; do
  [[ -f "${required}" ]] || {
    echo "[fail] missing required state 014 Sail override source: ${required}"
    exit 1
  }
done
cp "${SAIL_PIN_SOURCE_FILE}" "${SAIL_PIN_TARGET_FILE}"

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
      "hostManifests": {},
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
        },
        "userChannels": {
          "broadcasts": [
            "fdc3.instrument",
            "traderx.account"
          ],
          "listensFor": [
            "fdc3.instrument",
            "traderx.account"
          ]
        }
      }
    },
    {
      "appId": "traderx-mini",
      "name": "Mini TraderX",
      "title": "Mini TraderX",
      "description": "Compact TraderX companion view for account and instrument-scoped live positions.",
      "type": "web",
      "details": {
        "url": "__TRADERX_URL__/mini-traderx"
      },
      "hostManifests": {},
      "version": "0.1.0",
      "publisher": "FINOS",
      "icons": [
        {
          "src": "https://finos.org/wp-content/uploads/2018/03/finos-icon.svg"
        }
      ],
      "interop": {
        "intents": {
          "listensFor": {},
          "raises": {}
        },
        "userChannels": {
          "broadcasts": [
            "fdc3.instrument",
            "traderx.account"
          ],
          "listensFor": [
            "fdc3.instrument",
            "traderx.account"
          ]
        }
      }
    },
    {
      "appId": "traderx-intent-launcher",
      "name": "TraderX Intent Launcher",
      "title": "TraderX Intent Launcher",
      "description": "TraderX-owned helper app that raises TraderX intents for the current FDC3 instrument.",
      "type": "web",
      "details": {
        "url": "http://localhost:4040/"
      },
      "hostManifests": {},
      "version": "0.1.0",
      "publisher": "FINOS",
      "icons": [
        {
          "src": "http://localhost:4040/icon.svg"
        }
      ],
      "interop": {
        "intents": {
          "listensFor": {},
          "raises": {
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
          }
        },
        "userChannels": {
          "broadcasts": [],
          "listensFor": [
            "fdc3.instrument"
          ]
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

mkdir -p "${TARGET_FRONTEND_DIR}/main/fdc3/appd/v2"
node - "${SAIL_APPD_DIR}/traderx.appd.v2.json" "${TARGET_FRONTEND_DIR}/main/fdc3/appd/v2/apps" <<'NODE'
const fs = require('node:fs');
const [sourcePath, targetPath] = process.argv.slice(2);
const doc = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
const replaceTraderXUrl = (value) => {
  if (typeof value === 'string') {
    return value.replaceAll('__TRADERX_URL__', 'http://localhost:8080');
  }
  if (Array.isArray(value)) {
    return value.map(replaceTraderXUrl);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, next]) => [key, replaceTraderXUrl(next)]));
  }
  return value;
};
fs.writeFileSync(targetPath, `${JSON.stringify(replaceTraderXUrl(doc), null, 2)}\n`, 'utf8');
NODE

node - "${TARGET_FRONTEND_DIR}/angular.json" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const doc = JSON.parse(fs.readFileSync(path, 'utf8'));
const app = doc.projects?.['main-application']?.architect;
if (!app) {
  throw new Error('main-application architect section not found in angular.json');
}
const appdAsset = {
  glob: '**/*',
  input: 'main/fdc3',
  output: '/fdc3',
};
for (const targetName of ['build', 'test']) {
  const assets = app[targetName]?.options?.assets;
  if (!Array.isArray(assets)) {
    throw new Error(`${targetName}.options.assets must be an array`);
  }
  const alreadyConfigured = assets.some((asset) =>
    asset &&
    typeof asset === 'object' &&
    asset.input === appdAsset.input &&
    asset.output === appdAsset.output
  );
  if (!alreadyConfigured) {
    assets.push(appdAsset);
  }
}
fs.writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
NODE

# Ensure state-014 FDC3 v3 alpha client dependency is present in generated web
# UI before lockfiles are refreshed.
node - "${TARGET_FRONTEND_DIR}/package.json" <<'NODE'
const fs = require('node:fs');
const path = process.argv[2];
const doc = JSON.parse(fs.readFileSync(path, 'utf8'));
doc.dependencies = doc.dependencies || {};
delete doc.dependencies['@robmoffat/fdc3-get-agent'];
doc.dependencies['@finos/fdc3'] = '3.0.0-alpha.2';
if (doc.overrides && typeof doc.overrides === 'object' && !Array.isArray(doc.overrides)) {
  delete doc.overrides['@robmoffat/fdc3-get-agent'];
}
fs.writeFileSync(path, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
NODE

# State 014 overlays can update package manifests, so refresh lockfiles after
# overlay copy and package mutation to keep generated Docker/npm-ci builds
# deterministic.
bash "${ROOT}/pipeline/refresh-generated-node-lockfiles.sh" "${TARGET_FRONTEND_DIR}"

chmod +x \
  "${SAIL_BOOTSTRAP_DIR}/run-sail.sh" \
  "${SAIL_BOOTSTRAP_DIR}/apply-sail-demo-compat.sh" \
  "${SAIL_BOOTSTRAP_DIR}/merge-traderx-appd.sh"

echo "[done] rendered state 014 Sail artifacts into ${STATE_DIR}"
