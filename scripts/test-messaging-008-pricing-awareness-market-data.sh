#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
TRADE_SERVICE_URL="${2:-http://localhost:18092}"
ACCOUNT_ID="${3:-22214}"
SUBJECT_MAP_FILE="${4:-specs/008-pricing-awareness-market-data/system/messaging-subject-map.md}"
TIMEOUT_MS="${TIMEOUT_MS:-20000}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(git -C "${REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${REPO_ROOT}")"

resolve_subject_map_path() {
  local candidate="$1"
  if [[ -f "${candidate}" ]]; then
    echo "${candidate}"
    return
  fi
  if [[ -f "${REPO_ROOT}/${candidate}" ]]; then
    echo "${REPO_ROOT}/${candidate}"
    return
  fi
  if [[ -f "${WORKSPACE_ROOT}/${candidate}" ]]; then
    echo "${WORKSPACE_ROOT}/${candidate}"
    return
  fi
  echo "${WORKSPACE_ROOT}/${candidate}"
}

warn_uncovered_subjects() {
  local map_file="$1"
  shift
  local covered=("$@")
  local uncovered=0

  if [[ ! -f "${map_file}" ]]; then
    echo "[warn] subject map not found for coverage warnings: ${map_file}"
    return 0
  fi

  while IFS= read -r subject; do
    local is_covered=0
    for pattern in "${covered[@]}"; do
      if [[ "${subject}" == "${pattern}" ]]; then
        is_covered=1
        break
      fi
    done
    if [[ "${is_covered}" -eq 0 ]]; then
      echo "[warn] SUBJECT_WITHOUT_TRIGGER_COVERAGE: ${subject}"
      uncovered=$((uncovered + 1))
    fi
  done < <(sed -n 's/^- `\([^`]*\)`.*/\1/p' "${map_file}")

  if [[ "${uncovered}" -eq 0 ]]; then
    echo "[info] subject map coverage warnings: none"
  fi
}

echo "[check] message bus websocket reachability pre-check"
INGRESS_URL="${INGRESS_URL}" TIMEOUT_MS="${TIMEOUT_MS}" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const timeoutMs = Number(process.env.TIMEOUT_MS || '20000');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';

if (typeof WebSocket !== 'function') {
  console.error('[error] MESSAGE_BUS_UNREACHABLE: global WebSocket unavailable in this Node runtime');
  process.exit(31);
}

const ws = new WebSocket(wsUrl);
const timer = setTimeout(() => {
  console.error(`[error] MESSAGE_BUS_UNREACHABLE: timeout connecting to ${wsUrl}`);
  process.exit(31);
}, Math.min(timeoutMs, 8000));

ws.onopen = () => {
  clearTimeout(timer);
  ws.close();
  console.log('[info] message bus websocket reachable');
  process.exit(0);
};

ws.onerror = () => {
  clearTimeout(timer);
  console.error(`[error] MESSAGE_BUS_UNREACHABLE: websocket error for ${wsUrl}`);
  process.exit(31);
};
NODE

warn_uncovered_subjects \
  "$(resolve_subject_map_path "${SUBJECT_MAP_FILE}")" \
  "/trades" \
  "/accounts/<accountId>/trades" \
  "/accounts/<accountId>/positions" \
  "pricing.<TICKER>"

echo "[check] messaging flow assertions for state 008 subject map"
INGRESS_URL="${INGRESS_URL}" \
TRADE_SERVICE_URL="${TRADE_SERVICE_URL}" \
ACCOUNT_ID="${ACCOUNT_ID}" \
TIMEOUT_MS="${TIMEOUT_MS}" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const tradeServiceUrl = process.env.TRADE_SERVICE_URL || 'http://localhost:18092';
const accountId = Number(process.env.ACCOUNT_ID || '22214');
const timeoutMs = Number(process.env.TIMEOUT_MS || '20000');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';
const security = 'IBM';
const qty = 7000 + Math.floor(Math.random() * 500);

const subjectExpectations = {
  '/trades': (payload) => payload && payload.security === security && Number(payload.quantity) === qty && Number.isFinite(Number(payload.price)),
  [`/accounts/${accountId}/trades`]: (payload) => payload && payload.security === security && Number(payload.quantity) === qty && payload.state === 'Settled',
  [`/accounts/${accountId}/positions`]: (payload) => payload && payload.security === security && Number.isFinite(Number(payload.quantity)),
  [`pricing.${security}`]: (payload) => payload && payload.ticker === security && Number.isFinite(Number(payload.price)) && Number.isFinite(Number(payload.openPrice)) && Number.isFinite(Number(payload.closePrice)),
};

if (typeof WebSocket !== 'function') {
  console.error('[error] MESSAGE_BUS_UNREACHABLE: global WebSocket unavailable in this Node runtime');
  process.exit(31);
}

let buffer = '';
let pending = null;
let submitted = false;
const matched = new Set();
const sidByTopic = new Map(Object.keys(subjectExpectations).map((topic, idx) => [topic, idx + 1]));

function fail(code, message) {
  console.error(`[error] ${code}: ${message}`);
  process.exit(1);
}

function maybeDone() {
  if (matched.size === Object.keys(subjectExpectations).length) {
    console.log(`[info] messaging subjects validated: ${Array.from(matched).sort().join(', ')}`);
    process.exit(0);
  }
}

function handlePayload(subject, payload) {
  const validator = subjectExpectations[subject];
  if (!validator) {
    return;
  }
  if (validator(payload)) {
    matched.add(subject);
    maybeDone();
  }
}

function parseFrame(text, ws) {
  buffer += text;
  while (true) {
    if (pending) {
      const needed = pending.bytes + 2;
      if (buffer.length < needed) {
        return;
      }
      const payloadText = buffer.slice(0, pending.bytes);
      buffer = buffer.slice(needed);
      try {
        const parsed = JSON.parse(payloadText);
        const payload = parsed && typeof parsed === 'object' && parsed.payload ? parsed.payload : parsed;
        handlePayload(pending.subject, payload);
      } catch (_) {
        // ignore non-json
      }
      pending = null;
      continue;
    }

    const eol = buffer.indexOf('\r\n');
    if (eol < 0) {
      return;
    }
    const line = buffer.slice(0, eol);
    buffer = buffer.slice(eol + 2);
    if (!line) {
      continue;
    }
    if (line.startsWith('PING')) {
      ws.send('PONG\r\n');
      continue;
    }
    if (line.startsWith('INFO') || line.startsWith('PONG')) {
      continue;
    }
    if (line.startsWith('MSG ')) {
      const parts = line.split(' ');
      if (parts.length < 4) {
        continue;
      }
      const subject = parts[1];
      const bytes = Number(parts[parts.length - 1]);
      if (!Number.isFinite(bytes)) {
        continue;
      }
      pending = { subject, bytes };
    }
  }
}

async function submitTrade() {
  if (submitted) return;
  submitted = true;
  const response = await fetch(`${tradeServiceUrl}/trade/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ security, quantity: qty, accountId, side: 'Buy' }),
  });
  if (response.status !== 200) {
    const body = await response.text();
    fail('NO_MESSAGE_RECEIVED_ON_SUBJECT', `trade submit failed status=${response.status} body=${body}`);
  }
}

const ws = new WebSocket(wsUrl);
const timer = setTimeout(() => {
  const missing = Object.keys(subjectExpectations).filter((subject) => !matched.has(subject));
  fail('NO_MESSAGE_RECEIVED_ON_SUBJECT', `timed out; missing subjects: ${missing.join(', ')}`);
}, timeoutMs);

ws.onopen = async () => {
  ws.send('CONNECT {"protocol":1,"verbose":false,"pedantic":false,"echo":false}\r\n');
  for (const [topic, sid] of sidByTopic.entries()) {
    ws.send(`SUB ${topic} ${sid}\r\n`);
  }
  ws.send('PING\r\n');
  try {
    await submitTrade();
  } catch (err) {
    clearTimeout(timer);
    fail('NO_MESSAGE_RECEIVED_ON_SUBJECT', err.message);
  }
};

ws.onmessage = async (event) => {
  if (typeof event.data === 'string') {
    parseFrame(event.data, ws);
    return;
  }
  if (event.data instanceof Blob) {
    parseFrame(await event.data.text(), ws);
    return;
  }
  if (event.data instanceof ArrayBuffer) {
    parseFrame(new TextDecoder().decode(new Uint8Array(event.data)), ws);
  }
};

ws.onerror = () => {
  clearTimeout(timer);
  fail('MESSAGE_BUS_UNREACHABLE', `websocket error while connected to ${wsUrl}`);
};

process.on('exit', () => {
  clearTimeout(timer);
  try { ws.close(); } catch (_) {}
});
NODE

echo "[done] state 008 messaging smoke tests passed"
