#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
COMPONENTS_ROOT="${3:-${GENERATED_ROOT}/code/components}"
EXPLORER_ROOT="${TARGET_ROOT}/api-explorer"
CONTRACTS_ROOT="${EXPLORER_ROOT}/contracts"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/install-generated-api-explorer.sh <state-id> [target-root] [components-root]"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

mkdir -p "${CONTRACTS_ROOT}"

install_nats_ws_vendor() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "[fail] npm is required to vendor nats.ws for API explorer inspector"
    exit 1
  fi

  local explorer_abs
  explorer_abs="$(cd "${EXPLORER_ROOT}" && pwd)"
  local vendor_dir="${explorer_abs}/vendor/nats.ws"
  mkdir -p "${vendor_dir}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  (
    cd "${tmp_dir}"
    local pkg
    pkg="$(npm pack nats.ws --silent)"
    tar -xzf "${pkg}"
    cp package/esm/nats.js "${vendor_dir}/nats.js"
    cp package/LICENSE "${vendor_dir}/LICENSE-nats.ws"
  )
  rm -rf "${tmp_dir}"
}

install_nats_ws_vendor

cat > "${EXPLORER_ROOT}/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>TraderX API Docs</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
    <style>
      body { margin: 0; background: #f5f7fb; }
      .topbar {
        background: #0b233a;
        color: #fff;
        padding: 12px 16px;
        font-family: sans-serif;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
      }
      .topbar small { opacity: 0.8; }
      .topbar a {
        color: #9fd0ff;
        font-size: 14px;
        text-decoration: none;
        border: 1px solid rgba(159, 208, 255, 0.55);
        border-radius: 6px;
        padding: 6px 10px;
        white-space: nowrap;
      }
      .topbar-links {
        align-items: center;
        display: inline-flex;
        gap: 8px;
      }
      .topbar a:hover {
        background: rgba(159, 208, 255, 0.18);
      }
      #swagger-ui { max-width: 1300px; margin: 0 auto; }
    </style>
  </head>
  <body>
    <div class="topbar">
      <div>
        TraderX API Docs
        <small id="state-label"></small>
      </div>
      <div class="topbar-links">
        <a href="/">Back to App</a>
        <a id="pubsub-inspector-link" href="#">Open Pub/Sub Inspector</a>
      </div>
    </div>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    <script>
      function deriveRuntimeBasePath(service) {
        if (!service || !service.runtimeSpecPath) {
          return null;
        }

        const explicit = typeof service.runtimeBasePath === 'string' ? service.runtimeBasePath.trim() : '';
        if (explicit) {
          return explicit.startsWith('/') ? explicit : `/${explicit}`;
        }

        if (!service.runtimeSpecPath.startsWith('/')) {
          return null;
        }

        const segments = service.runtimeSpecPath.split('/').filter(Boolean);
        if (segments.length < 2) {
          return null;
        }
        return `/${segments[0]}`;
      }

      function resolveSpecKey(specUrl) {
        if (!specUrl || typeof specUrl !== 'string') {
          return null;
        }
        try {
          return new URL(specUrl, window.location.origin).toString();
        } catch (_error) {
          return null;
        }
      }

      function selectedSpecUrl(ui) {
        if (!ui || !ui.specSelectors || typeof ui.specSelectors.url !== 'function') {
          return null;
        }
        const raw = ui.specSelectors.url();
        if (!raw) {
          return null;
        }
        if (typeof raw === 'string') {
          return raw;
        }
        if (typeof raw.toJS === 'function') {
          return raw.toJS();
        }
        return String(raw);
      }

      async function bootstrap() {
        const response = await fetch('./catalog.json', { cache: 'no-cache' });
        if (!response.ok) {
          throw new Error('failed to load API catalog');
        }

        const catalog = await response.json();
        const services = Array.isArray(catalog.services) ? catalog.services : [];
        if (services.length === 0) {
          throw new Error('API catalog is empty');
        }

        const urls = services.map((service) => ({ name: service.name, url: service.specUrl }));
        const knownPrefixes = [];
        const serviceBySpec = new Map();
        for (const service of services) {
          const specKey = resolveSpecKey(service.specUrl);
          const runtimeBasePath = deriveRuntimeBasePath(service);
          if (runtimeBasePath) {
            knownPrefixes.push(runtimeBasePath);
          }
          if (specKey) {
            serviceBySpec.set(specKey, {
              ...service,
              runtimeBasePath,
            });
          }
        }

        const stateLabel = document.getElementById('state-label');
        if (stateLabel && catalog.stateId) {
          stateLabel.textContent = ` - state ${catalog.stateId}`;
        }
        const inspectorLink = document.getElementById('pubsub-inspector-link');
        if (inspectorLink) {
          const base = window.location.href.replace(/\/[^/]*$/, '/');
          inspectorLink.href = `${base}pubsub-inspector`;
        }

        window.ui = SwaggerUIBundle({
          dom_id: '#swagger-ui',
          urls,
          deepLinking: true,
          defaultModelsExpandDepth: -1,
          displayRequestDuration: true,
          docExpansion: 'list',
          filter: true,
          layout: 'StandaloneLayout',
          persistAuthorization: true,
          presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
          requestInterceptor: (request) => {
            if (!request || !request.url) {
              return request;
            }

            const activeSpec = selectedSpecUrl(window.ui);
            const activeSpecKey = resolveSpecKey(activeSpec);
            const service = activeSpecKey ? serviceBySpec.get(activeSpecKey) : null;
            if (!service || !service.runtimeBasePath) {
              return request;
            }

            let parsed;
            try {
              parsed = new URL(request.url, window.location.origin);
            } catch (_error) {
              return request;
            }

            const hasKnownPrefix = knownPrefixes.some((prefix) =>
              parsed.pathname === prefix || parsed.pathname.startsWith(`${prefix}/`));
            if (hasKnownPrefix) {
              return request;
            }

            const normalizedPath = parsed.pathname.startsWith('/') ? parsed.pathname : `/${parsed.pathname}`;
            parsed.pathname = `${service.runtimeBasePath}${normalizedPath}`.replace(/\/{2,}/g, '/');
            parsed.host = window.location.host;
            parsed.protocol = window.location.protocol;
            request.url = parsed.toString();
            return request;
          },
        });
      }

      bootstrap().catch((error) => {
        const el = document.getElementById('swagger-ui');
        if (!el) return;
        el.innerHTML = `<pre style="padding:16px;color:#a40000;">${String(error)}</pre>`;
      });
    </script>
  </body>
</html>
EOF

cat > "${EXPLORER_ROOT}/pubsub-inspector.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>TraderX Pub/Sub Inspector</title>
    <style>
      :root {
        --bg: #f3f7fb;
        --panel: #ffffff;
        --ink: #0f172a;
        --muted: #667085;
        --border: #d8e2ee;
        --accent: #0a66c2;
        --ok: #1a7f37;
        --bad: #b42318;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        background: var(--bg);
        color: var(--ink);
        font-family: ui-sans-serif, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
      }
      .top {
        background: #0b233a;
        color: #fff;
        padding: 12px 16px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 12px;
      }
      .top a {
        color: #9fd0ff;
        text-decoration: none;
      }
      .shell {
        padding: 12px;
        display: grid;
        grid-template-columns: 340px 1fr;
        gap: 12px;
      }
      .panel {
        background: var(--panel);
        border: 1px solid var(--border);
        border-radius: 10px;
      }
      .panel h2 {
        margin: 0;
        font-size: 15px;
        padding: 10px 12px;
        border-bottom: 1px solid var(--border);
      }
      .panel .body {
        padding: 10px 12px;
      }
      .status {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        font-weight: 600;
      }
      .dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: #9ca3af;
      }
      .dot.connected { background: var(--ok); }
      .dot.error { background: var(--bad); }
      .muted { color: var(--muted); font-size: 12px; }
      .topics {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
      }
      .topic-btn {
        border: 1px solid var(--border);
        background: #f8fbff;
        color: #0f172a;
        border-radius: 999px;
        padding: 6px 10px;
        font-size: 12px;
        cursor: pointer;
      }
      .topic-btn.wildcard {
        border-color: #7c92ff;
        background: #eef1ff;
      }
      .topic-btn.parameterized {
        border-color: #f59e0b;
        background: #fff8e6;
      }
      .row {
        display: flex;
        gap: 8px;
        align-items: center;
        margin-top: 8px;
      }
      input[type="text"] {
        width: 100%;
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 8px 10px;
        font-size: 13px;
      }
      button {
        border: 1px solid var(--border);
        border-radius: 8px;
        background: #fff;
        padding: 7px 10px;
        font-size: 12px;
        cursor: pointer;
      }
      .btn-primary {
        border-color: var(--accent);
        background: var(--accent);
        color: #fff;
      }
      ul.subs {
        margin: 8px 0 0;
        padding: 0;
        list-style: none;
      }
      .subs li {
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 7px 9px;
        margin-top: 6px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
      }
      .subs code {
        font-size: 12px;
      }
      .feed-toolbar {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 10px 12px;
        border-bottom: 1px solid var(--border);
        flex-wrap: wrap;
      }
      #feed {
        max-height: calc(100vh - 210px);
        overflow: auto;
        padding: 10px 12px;
      }
      details.msg {
        border: 1px solid var(--border);
        border-radius: 8px;
        background: #fff;
        padding: 6px 8px;
        margin-bottom: 8px;
      }
      details.msg summary {
        cursor: pointer;
        font-size: 12px;
        line-height: 1.4;
      }
      .topic {
        font-weight: 700;
      }
      .pattern {
        color: #64748b;
      }
      pre {
        margin: 8px 0 0;
        white-space: pre-wrap;
        word-break: break-word;
        font-size: 12px;
      }
      @media (max-width: 980px) {
        .shell { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <div class="top">
      <div>
        TraderX Pub/Sub Inspector
      </div>
      <div>
        <a href="./">Back to API Docs</a>
        <a href="/" style="margin-left:8px;">Back to App</a>
      </div>
    </div>
    <div class="shell">
      <div class="panel">
        <h2>Connection & Subscriptions</h2>
        <div class="body">
          <div class="status"><span id="status-dot" class="dot"></span><span id="status-text">connecting</span></div>
          <div id="status-note" class="muted" style="margin-top:4px;"></div>

          <div style="margin-top:12px; font-size:12px; font-weight:600;">Generated subjects</div>
          <div id="topic-buttons" class="topics" style="margin-top:6px;"></div>

          <div class="row">
            <input id="topic-input" type="text" placeholder="Topic (for example pricing.* or /orders)" />
            <button id="subscribe-btn" class="btn-primary">Subscribe</button>
          </div>

          <div style="margin-top:12px; font-size:12px; font-weight:600;">Active subscriptions</div>
          <ul id="subscriptions" class="subs"></ul>
        </div>
      </div>

      <div class="panel">
        <div class="feed-toolbar">
          <input id="filter-input" type="text" placeholder="Filter by delivery topic or payload text" style="flex:1;min-width:220px;" />
          <button id="pause-btn">Pause</button>
          <button id="clear-btn">Clear</button>
          <div class="muted">
            Session messages: <strong id="total-count">0</strong> |
            Buffer: <strong id="buffer-count">0</strong>/2000
          </div>
        </div>
        <div id="feed"></div>
      </div>
    </div>
    <script type="module">
      import { connect, StringCodec } from './vendor/nats.ws/nats.js';

      const MAX_BUFFER = 2000;
      const statusDot = document.getElementById('status-dot');
      const statusText = document.getElementById('status-text');
      const statusNote = document.getElementById('status-note');
      const topicButtons = document.getElementById('topic-buttons');
      const topicInput = document.getElementById('topic-input');
      const subscribeBtn = document.getElementById('subscribe-btn');
      const subscriptionsList = document.getElementById('subscriptions');
      const filterInput = document.getElementById('filter-input');
      const pauseBtn = document.getElementById('pause-btn');
      const clearBtn = document.getElementById('clear-btn');
      const feed = document.getElementById('feed');
      const totalCountEl = document.getElementById('total-count');
      const bufferCountEl = document.getElementById('buffer-count');
      const sc = StringCodec();

      let nc = null;
      let paused = false;
      let feedDirtyWhilePaused = false;
      let totalMessages = 0;
      let reconnectAttempts = 0;
      let nextMessageId = 1;
      const messages = [];
      const subscriptions = new Map();
      const seedTopics = [];

      function setStatus(state, text, note = '') {
        statusText.textContent = text;
        statusDot.className = `dot ${state}`;
        statusNote.textContent = note;
      }

      function formatTime(date) {
        const pad = (n, width = 2) => String(n).padStart(width, '0');
        return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
      }

      function parseTopicEntry(raw) {
        const base = String(raw || '').trim();
        if (!base) {
          return null;
        }
        const wildcard = base.includes('*') || base.includes('>');
        const parameterized = /<[^>]+>/.test(base) || /{[^}]+}/.test(base);
        return {
          subject: base,
          prefill: base.replace(/<([^>]+)>/g, '{$1}'),
          wildcard,
          parameterized,
        };
      }

      function deriveNatsWsUrl() {
        const natsUrl = new URL('../../nats-ws', window.location.href);
        natsUrl.protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return natsUrl.toString();
      }

      function renderCounts() {
        totalCountEl.textContent = String(totalMessages);
        bufferCountEl.textContent = String(messages.length);
      }

      function renderSubscriptions() {
        subscriptionsList.innerHTML = '';
        const entries = Array.from(subscriptions.values())
          .sort((a, b) => a.pattern.localeCompare(b.pattern));
        if (entries.length === 0) {
          const li = document.createElement('li');
          li.innerHTML = '<span class="muted">No active subscriptions</span>';
          subscriptionsList.appendChild(li);
          return;
        }
        for (const entry of entries) {
          const li = document.createElement('li');
          const left = document.createElement('div');
          left.innerHTML = `<code>${entry.pattern}</code><div class="muted">messages: ${entry.count}</div>`;
          const remove = document.createElement('button');
          remove.textContent = '×';
          remove.title = `Unsubscribe ${entry.pattern}`;
          remove.onclick = () => unsubscribe(entry.pattern);
          li.appendChild(left);
          li.appendChild(remove);
          subscriptionsList.appendChild(li);
        }
      }

      function renderFeed() {
        const filter = filterInput.value.trim().toLowerCase();
        const rows = filter
          ? messages.filter((msg) => msg.deliveryTopic.toLowerCase().includes(filter) || msg.payloadPreviewLower.includes(filter))
          : messages;
        feed.innerHTML = '';
        for (const msg of rows.slice().reverse()) {
          const details = document.createElement('details');
          details.className = 'msg';
          const summary = document.createElement('summary');
          const patternPart = msg.subscriptionPattern !== msg.deliveryTopic
            ? ` <span class="pattern">(matched by ${msg.subscriptionPattern})</span>`
            : '';
          summary.innerHTML = `<span class="topic">${msg.deliveryTopic}</span>${patternPart} <span class="muted">${msg.receivedAt}</span> <span class="muted">${msg.payloadPreview}</span>`;
          const pre = document.createElement('pre');
          pre.textContent = msg.payloadPretty;
          details.appendChild(summary);
          details.appendChild(pre);
          feed.appendChild(details);
        }
      }

      function pushMessage(subscriptionPattern, natsMsg) {
        let decoded = '';
        try {
          decoded = sc.decode(natsMsg.data);
        } catch (_error) {
          decoded = '[binary payload]';
        }
        let payloadPretty = decoded;
        try {
          payloadPretty = JSON.stringify(JSON.parse(decoded), null, 2);
        } catch (_error) {
          payloadPretty = decoded;
        }
        const preview = decoded.length > 80 ? `${decoded.slice(0, 80)}...` : decoded;
        messages.push({
          id: nextMessageId++,
          deliveryTopic: String(natsMsg.subject || subscriptionPattern),
          subscriptionPattern,
          receivedAt: formatTime(new Date()),
          payloadPreview: preview,
          payloadPreviewLower: `${String(natsMsg.subject || '')} ${decoded}`.toLowerCase(),
          payloadPretty,
        });
        if (messages.length > MAX_BUFFER) {
          messages.shift();
        }
        totalMessages += 1;
        const entry = subscriptions.get(subscriptionPattern);
        if (entry) {
          entry.count += 1;
        }
        renderCounts();
        renderSubscriptions();
        if (paused) {
          feedDirtyWhilePaused = true;
          return;
        }
        renderFeed();
      }

      function unsubscribe(pattern) {
        const entry = subscriptions.get(pattern);
        if (!entry) {
          return;
        }
        try {
          entry.subscription.unsubscribe();
        } catch (_error) {}
        subscriptions.delete(pattern);
        renderSubscriptions();
      }

      async function subscribe(pattern) {
        const normalized = String(pattern || '').trim();
        if (!normalized) {
          return;
        }
        if (!nc) {
          setStatus('error', 'disconnected', 'Cannot subscribe until connected');
          return;
        }
        if (subscriptions.has(normalized)) {
          return;
        }
        const subscription = nc.subscribe(normalized);
        const entry = { pattern: normalized, subscription, count: 0 };
        subscriptions.set(normalized, entry);
        renderSubscriptions();
        (async () => {
          for await (const msg of subscription) {
            pushMessage(normalized, msg);
          }
        })().catch((error) => {
          setStatus('error', 'subscription error', String(error && error.message ? error.message : error));
          subscriptions.delete(normalized);
          renderSubscriptions();
        });
      }

      function clearFeed() {
        messages.length = 0;
        for (const entry of subscriptions.values()) {
          entry.count = 0;
        }
        renderCounts();
        renderSubscriptions();
        renderFeed();
      }

      function renderSeedButtons(subjects) {
        topicButtons.innerHTML = '';
        const unique = new Set();
        for (const subject of subjects) {
          const topic = parseTopicEntry(subject.pattern || subject.subject || subject);
          if (!topic || unique.has(topic.subject)) {
            continue;
          }
          unique.add(topic.subject);
          seedTopics.push(topic);
          const button = document.createElement('button');
          button.className = `topic-btn${topic.wildcard ? ' wildcard' : ''}${topic.parameterized ? ' parameterized' : ''}`;
          button.textContent = topic.subject;
          if (topic.parameterized) {
            button.title = 'Prefill pattern in topic input';
            button.onclick = () => {
              topicInput.value = topic.prefill;
              topicInput.focus();
            };
          } else {
            button.title = 'Subscribe';
            button.onclick = () => subscribe(topic.subject);
          }
          topicButtons.appendChild(button);
        }
      }

      async function loadCatalogSubjects() {
        const response = await fetch('./catalog.json', { cache: 'no-cache' });
        if (!response.ok) {
          return [];
        }
        const catalog = await response.json();
        return Array.isArray(catalog.messagingSubjects) ? catalog.messagingSubjects : [];
      }

      async function connectLoop() {
        const wsUrl = deriveNatsWsUrl();
        while (true) {
          try {
            setStatus('', 'connecting', wsUrl);
            nc = await connect({
              servers: wsUrl,
              maxReconnectAttempts: 0,
              noEcho: true,
            });
            reconnectAttempts = 0;
            setStatus('connected', 'connected', wsUrl);
            const toSubscribe = Array.from(subscriptions.keys());
            subscriptions.clear();
            renderSubscriptions();
            for (const pattern of toSubscribe) {
              await subscribe(pattern);
            }
            await nc.closed();
            setStatus('error', 'disconnected', 'Connection closed');
          } catch (error) {
            const waitMs = Math.min(30000, 500 * (2 ** reconnectAttempts));
            reconnectAttempts += 1;
            setStatus('error', 'reconnecting', `${wsUrl} (retry in ${waitMs} ms)`);
            await new Promise((resolve) => setTimeout(resolve, waitMs));
          }
        }
      }

      subscribeBtn.addEventListener('click', () => subscribe(topicInput.value));
      topicInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
          subscribe(topicInput.value);
        }
      });
      filterInput.addEventListener('input', () => renderFeed());
      pauseBtn.addEventListener('click', () => {
        paused = !paused;
        pauseBtn.textContent = paused ? 'Resume' : 'Pause';
        if (!paused && feedDirtyWhilePaused) {
          feedDirtyWhilePaused = false;
          renderFeed();
        }
      });
      clearBtn.addEventListener('click', clearFeed);

      renderCounts();
      renderSubscriptions();
      loadCatalogSubjects()
        .then((subjects) => renderSeedButtons(subjects))
        .catch(() => renderSeedButtons([]));
      connectLoop();
    </script>
  </body>
</html>
EOF

# Keep a no-extension alias to avoid relative redirect pitfalls behind
# clean-URL static servers while preserving direct .html compatibility.
cp "${EXPLORER_ROOT}/pubsub-inspector.html" "${EXPLORER_ROOT}/pubsub-inspector"

ROOT="${ROOT}" STATE_ID="${STATE_ID}" TARGET_ROOT="${TARGET_ROOT}" EXPLORER_ROOT="${EXPLORER_ROOT}" node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.ROOT;
const stateId = process.env.STATE_ID;
const targetRoot = process.env.TARGET_ROOT;
const explorerRoot = process.env.EXPLORER_ROOT;
const contractsRoot = path.join(explorerRoot, 'contracts');

const catalogPath = path.join(root, 'catalog', 'state-catalog.json');
const stateCatalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));

const defaults = {
  mountPath: '/api/docs',
  services: [
    {
      id: 'account-service',
      name: 'Account Service',
      detectPath: 'account-service',
      runtimeSpecPath: '/account-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/account-service/openapi.yaml',
    },
    {
      id: 'people-service',
      name: 'People Service',
      detectPath: 'people-service',
      runtimeSpecPath: '/people-service/swagger/v1/swagger.json',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/people-service/openapi.yaml',
    },
    {
      id: 'position-service',
      name: 'Position Service',
      detectPath: 'position-service',
      runtimeSpecPath: '/position-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/position-service/openapi.yaml',
    },
    {
      id: 'reference-data',
      name: 'Reference Data',
      detectPath: 'reference-data',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml',
    },
    {
      id: 'trade-processor',
      name: 'Trade Processor',
      detectPath: 'trade-processor',
      runtimeSpecPath: '/trade-processor/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/trade-processor/openapi.yaml',
    },
    {
      id: 'trade-service',
      name: 'Trade Service',
      detectPath: 'trade-service',
      runtimeSpecPath: '/trade-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/trade-service/openapi.yaml',
    },
    {
      id: 'order-matcher',
      name: 'Order Matcher',
      detectPath: 'order-matcher',
      runtimeSpecPath: '/order-matcher/v3/api-docs',
    },
  ],
};

const apiCatalog = stateCatalog.apiCatalog ?? defaults;
const mountPath = apiCatalog.mountPath ?? defaults.mountPath;
const serviceDefs = Array.isArray(apiCatalog.services) && apiCatalog.services.length > 0
  ? apiCatalog.services
  : defaults.services;

const messageSubjectsPath = path.join(root, 'specs', stateId, 'system', 'messaging-subject-map.md');

const parseMessagingSubjects = (markdown) => {
  const lines = String(markdown || '').split(/\r?\n/);
  const subjects = [];
  let current = null;
  for (const line of lines) {
    const familyMatch = line.match(/^\s*-\s+`([^`]+)`\s*$/);
    if (familyMatch) {
      current = {
        subject: familyMatch[1].trim(),
        wildcard: false,
        wildcardPattern: null,
      };
      subjects.push(current);
      continue;
    }
    if (!current) {
      continue;
    }
    const wildcardMatch = line.match(/^\s*-\s+wildcard:\s+`?yes`?(?:\s+\(`([^`]+)`\))?/i);
    if (wildcardMatch) {
      current.wildcard = true;
      current.wildcardPattern = wildcardMatch[1] ? wildcardMatch[1].trim() : null;
    }
  }
  return subjects.map((entry) => {
    const pattern = entry.wildcardPattern || entry.subject;
    return {
      subject: entry.subject,
      pattern,
      wildcard: Boolean(entry.wildcard),
      parameterized: /<[^>]+>/.test(entry.subject) || /{[^}]+}/.test(entry.subject),
      prefillPattern: entry.subject.replace(/<([^>]+)>/g, '{$1}'),
    };
  });
};

const deriveRuntimeBasePath = (def) => {
  if (typeof def.runtimeBasePath === 'string' && def.runtimeBasePath.trim()) {
    const explicit = def.runtimeBasePath.trim();
    return explicit.startsWith('/') ? explicit : `/${explicit}`;
  }
  const runtimeSpecPath = typeof def.runtimeSpecPath === 'string' ? def.runtimeSpecPath : '';
  if (!runtimeSpecPath.startsWith('/')) {
    return null;
  }
  const segments = runtimeSpecPath.split('/').filter(Boolean);
  if (segments.length < 2) {
    return null;
  }
  return `/${segments[0]}`;
};

const targetHas = (relativePath) =>
  fs.existsSync(path.join(targetRoot, relativePath));

const contracts = [];
const services = [];

for (const def of serviceDefs) {
  if (def.detectPath && !targetHas(def.detectPath)) {
    continue;
  }

  const contractName = `${def.id}-openapi.yaml`;
  const contractFile = def.contractPath ? path.join(root, def.contractPath) : null;
  const hasContract = Boolean(contractFile && fs.existsSync(contractFile));
  if (hasContract) {
    const outFile = path.join(contractsRoot, contractName);
    fs.copyFileSync(contractFile, outFile);
    contracts.push(contractName);
  }

  const contractUrl = hasContract ? `${mountPath}/contracts/${contractName}` : null;
  const runtimeSpecPath = def.runtimeSpecPath || null;
  const specUrl = runtimeSpecPath || contractUrl;
  if (!specUrl) {
    continue;
  }

  services.push({
    id: def.id,
    name: def.name || def.id,
    specUrl,
    runtimeSpecPath,
    runtimeBasePath: deriveRuntimeBasePath(def),
    contractUrl,
    interactive: Boolean(runtimeSpecPath),
  });
}

const runtimeCatalog = {
  generatedAtUtc: new Date().toISOString(),
  stateId,
  mountPath,
  services,
  messagingSubjects: fs.existsSync(messageSubjectsPath)
    ? parseMessagingSubjects(fs.readFileSync(messageSubjectsPath, 'utf8'))
    : [],
};

fs.writeFileSync(path.join(explorerRoot, 'catalog.json'), JSON.stringify(runtimeCatalog, null, 2) + '\n');
NODE

install_edge_proxy_explorer() {
  local edge_component="${COMPONENTS_ROOT}/edge-proxy-specfirst"
  local edge_server="${edge_component}/src/server.js"
  if [[ ! -f "${edge_server}" ]]; then
    return 0
  fi

  mkdir -p "${edge_component}/api-explorer"
  cp -R "${EXPLORER_ROOT}/." "${edge_component}/api-explorer/"

  cat > "${edge_server}" <<'EOF'
const fs = require('fs');
const path = require('path');
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function buildPathRewrite(prefix, rewritePrefix) {
  if (rewritePrefix === null || rewritePrefix === undefined) {
    return undefined;
  }
  const prefixRegex = new RegExp(`^${escapeRegex(prefix)}`);
  return (requestPath) => requestPath.replace(prefixRegex, rewritePrefix);
}

function loadRoutesConfig() {
  const configPath =
    process.env.EDGE_PROXY_ROUTES_FILE ||
    path.resolve(__dirname, '..', 'config', 'routes.json');
  const raw = fs.readFileSync(configPath, 'utf8');
  const config = JSON.parse(raw);
  if (!config.webTarget || !Array.isArray(config.apiRoutes)) {
    throw new Error(`invalid route config file: ${configPath}`);
  }
  return { configPath, config };
}

function createApp() {
  const app = express();
  const { configPath, config } = loadRoutesConfig();
  const port = Number(process.env.EDGE_PROXY_PORT || config.defaultPort || 18080);

  app.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      state: process.env.EDGE_PROXY_STATE_ID || '002-edge-proxy-uncontainerized',
      routesFile: configPath,
    });
  });

  const apiExplorerDir = path.resolve(__dirname, '..', 'api-explorer');
  if (fs.existsSync(path.join(apiExplorerDir, 'index.html'))) {
    app.get('/api/docs', (_req, res) => {
      res.redirect('/api/docs/');
    });
    app.use('/api/docs', express.static(apiExplorerDir));
  }

  for (const route of config.apiRoutes) {
    if (!route.prefix || !route.target) {
      throw new Error(`invalid api route entry in ${configPath}`);
    }
    app.use(route.prefix, createProxyMiddleware({
      target: route.target,
      changeOrigin: true,
      ws: Boolean(route.ws),
      xfwd: true,
      pathRewrite: buildPathRewrite(route.prefix, route.rewritePrefix),
      logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn',
      on: {
        proxyReq: (proxyReq) => {
          proxyReq.setHeader('X-Forwarded-Prefix', route.prefix);
        },
      },
    }));
  }

  const webTarget = process.env.EDGE_PROXY_WEB_TARGET || config.webTarget;
  app.use('/', createProxyMiddleware({
    target: webTarget,
    changeOrigin: true,
    ws: true,
    xfwd: true,
    logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn',
  }));
  return { app, port };
}

const { app, port } = createApp();
app.listen(port, () => {
  console.log(`[ready] edge-proxy listening on :${port}`);
});
EOF

  echo "[ok] installed standalone API explorer into edge-proxy component"
}

ensure_compose_ingress_explorer() {
  local ingress_dir="${TARGET_ROOT}/ingress"
  local ingress_conf="${ingress_dir}/nginx.traderx.conf.template"
  local ingress_dockerfile="${ingress_dir}/Dockerfile.compose"

  if [[ ! -f "${ingress_conf}" ]]; then
    return 0
  fi

  mkdir -p "${ingress_dir}/api-explorer"
  cp -R "${EXPLORER_ROOT}/." "${ingress_dir}/api-explorer/"

  if [[ -f "${ingress_dockerfile}" ]] && ! rg -q 'COPY api-explorer/ /usr/share/nginx/html/api-docs/' "${ingress_dockerfile}"; then
    cat >> "${ingress_dockerfile}" <<'EOF'
COPY api-explorer/ /usr/share/nginx/html/api-docs/
EOF
  fi

  if ! rg -q 'location /api/docs/' "${ingress_conf}"; then
    local tmp_file
    tmp_file="$(mktemp)"
    awk '
      BEGIN {
        inserted = 0
      }
      {
        if (!inserted && $0 ~ /^[[:space:]]*location[[:space:]]+\/[[:space:]]*\{/) {
          print "    location = /api/docs {"
          print "        return 301 /api/docs/;"
          print "    }"
          print ""
          print "    location /api/docs/ {"
          print "        alias /usr/share/nginx/html/api-docs/;"
          print "        index index.html;"
          print "        try_files $uri $uri/ /api/docs/index.html;"
          print "    }"
          print ""
          inserted = 1
        }
        print
      }
    ' "${ingress_conf}" > "${tmp_file}"
    mv "${tmp_file}" "${ingress_conf}"
  fi

  echo "[ok] installed standalone API explorer into compose ingress"
}

ensure_kubernetes_explorer() {
  local base_dir="${TARGET_ROOT}/kubernetes-runtime/manifests/base"
  local edge_proxy_conf="${base_dir}/edge-proxy-configmap.yaml"
  local kustomization_file="${base_dir}/kustomization.yaml"
  local build_plan_file="${TARGET_ROOT}/kubernetes-runtime/build-plan.json"
  local explorer_image="traderx-api-explorer:local"

  if [[ ! -d "${base_dir}" || ! -f "${edge_proxy_conf}" || ! -f "${kustomization_file}" ]]; then
    return 0
  fi

  local cm_file="${base_dir}/api-explorer-configmap.yaml"
  local deploy_file="${base_dir}/api-explorer-deployment.yaml"
  local svc_file="${base_dir}/api-explorer-service.yaml"
  local explorer_dockerfile="${EXPLORER_ROOT}/Dockerfile"

  cat > "${explorer_dockerfile}" <<'EOF'
FROM nginx:1.27-alpine
COPY . /usr/share/nginx/html/api/docs/
EOF
  rm -f "${EXPLORER_ROOT}/.dockerignore"
  rm -f "${cm_file}"

  {
    echo "apiVersion: apps/v1"
    echo "kind: Deployment"
    echo "metadata:"
    echo "  name: api-explorer"
    echo "  namespace: traderx"
    echo "  labels:"
    echo "    app: api-explorer"
    echo "spec:"
    echo "  replicas: 1"
    echo "  selector:"
    echo "    matchLabels:"
    echo "      app: api-explorer"
    echo "  template:"
    echo "    metadata:"
    echo "      labels:"
    echo "        app: api-explorer"
    echo "    spec:"
    echo "      containers:"
    echo "        - name: api-explorer"
    echo "          image: ${explorer_image}"
    echo "          imagePullPolicy: IfNotPresent"
    echo "          ports:"
    echo "            - containerPort: 80"
    echo "              name: http"
  } > "${deploy_file}"

  cat > "${svc_file}" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: api-explorer
  namespace: traderx
  labels:
    app: api-explorer
spec:
  selector:
    app: api-explorer
  ports:
    - port: 8080
      targetPort: 80
      protocol: TCP
      name: http
EOF

  if ! rg -q 'location /api/docs/' "${edge_proxy_conf}"; then
    local tmp_file
    tmp_file="$(mktemp)"
    awk '
      BEGIN {
        inserted = 0
      }
      {
        if (!inserted && $0 ~ /^[[:space:]]*location[[:space:]]+\/[[:space:]]*\{/) {
          print "        location = /api/docs {"
          print "            return 301 /api/docs/;"
          print "        }"
          print "    "
          print "        location /api/docs/ {"
          print "            proxy_pass http://api-explorer:8080/api/docs/;"
          print "            proxy_http_version 1.1;"
          print "            proxy_set_header Host $http_host;"
          print "            proxy_set_header X-Forwarded-Proto $scheme;"
          print "            proxy_set_header X-Forwarded-Prefix /api/docs;"
          print "        }"
          print "    "
          inserted = 1
        }
        print
      }
    ' "${edge_proxy_conf}" > "${tmp_file}"
    mv "${tmp_file}" "${edge_proxy_conf}"
  fi

  if ! rg -q 'api-explorer-deployment.yaml' "${kustomization_file}"; then
    cat >> "${kustomization_file}" <<'EOF'
  - api-explorer-deployment.yaml
  - api-explorer-service.yaml
EOF
  fi
  perl -0pi -e 's#^\s*-\s*api-explorer-configmap\.yaml\s*\n##mg' "${kustomization_file}"

  if [[ -f "${build_plan_file}" ]]; then
    local tmp_plan
    tmp_plan="$(mktemp)"
    jq '
      .images = (
        (.images // [])
        | map(select(.name != "api-explorer"))
        + [{
          "name": "api-explorer",
          "image": "traderx-api-explorer:local",
          "context": "api-explorer",
          "dockerfile": "Dockerfile"
        }]
      )
      | .deployments = (
        (.deployments // [])
        | map(select(. != "api-explorer"))
        + ["api-explorer"]
      )
    ' "${build_plan_file}" > "${tmp_plan}"
    mv "${tmp_plan}" "${build_plan_file}"
  fi

  echo "[ok] installed standalone API explorer into Kubernetes manifests"
}

install_edge_proxy_explorer
ensure_compose_ingress_explorer
ensure_kubernetes_explorer

echo "[ok] installed standalone API explorer assets for ${STATE_ID}"
