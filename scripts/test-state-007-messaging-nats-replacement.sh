#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/messaging-nats-replacement/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 007-messaging-nats-replacement"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 10 ]]; then
  echo "[error] expected 10+ running services, got ${running_services}"
  exit 1
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^trade-feed$'; then
  echo "[error] state 007 runtime must not contain trade-feed service"
  exit 1
fi

echo "[check] nginx ingress health endpoint"
health_headers="$(curl -sS -i "${INGRESS_URL}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress /health"
  exit 1
}

echo "[check] ingress UI root"
ui_headers="$(curl -sS -i "${INGRESS_URL}/" | sed -n '1,20p')"
echo "${ui_headers}"
printf '%s\n' "${ui_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress UI root"
  exit 1
}

echo "[check] NATS broker monitor endpoint"
nats_varz_headers="$(curl -sS -i "http://localhost:8222/varz" | sed -n '1,30p')"
echo "${nats_varz_headers}"
printf '%s\n' "${nats_varz_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from NATS monitor endpoint"
  exit 1
}
curl -sS "http://localhost:8222/varz" | jq -e '.server_id and .max_payload and .proto' >/dev/null || {
  echo "[error] NATS /varz payload missing required keys"
  exit 1
}

echo "[check] ingress websocket upgrade route to NATS"
ws_headers="$(
  curl -sS -i --max-time 5 \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "${INGRESS_URL}/nats-ws" 2>/dev/null | sed -n '1,30p' || true
)"
echo "${ws_headers}"
printf '%s\n' "${ws_headers}" | grep -Eq "HTTP/1\\.[01] 101|HTTP/2 101" || {
  echo "[error] expected websocket 101 response from ${INGRESS_URL}/nats-ws"
  exit 1
}

echo "[check] account realtime stream over NATS websocket after trade submit"
INGRESS_URL="${INGRESS_URL}" TRADE_SERVICE_URL="http://localhost:18092" ACCOUNT_ID="22214" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const tradeServiceUrl = process.env.TRADE_SERVICE_URL || 'http://localhost:18092';
const accountId = Number(process.env.ACCOUNT_ID || '22214');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';
const tradeTopic = `/accounts/${accountId}/trades`;
const positionTopic = `/accounts/${accountId}/positions`;
const qty = 7000 + Math.floor(Math.random() * 500);
const security = 'IBM';
const timeoutMs = 20000;

if (typeof WebSocket !== 'function') {
  console.error('[error] global WebSocket is unavailable in this Node runtime');
  process.exit(1);
}

let buffer = '';
let pending = null;
let sawTrade = false;
let sawPosition = false;
let submitted = false;
const sidByTopic = new Map([
  [tradeTopic, 1],
  [positionTopic, 2],
]);

function fail(message) {
  console.error(`[error] ${message}`);
  process.exit(1);
}

function maybeDone() {
  if (sawTrade && sawPosition) {
    console.log('[info] account trade/position realtime updates received via NATS websocket');
    process.exit(0);
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
        if (pending.subject === tradeTopic &&
            payload &&
            payload.security === security &&
            Number(payload.quantity) === qty &&
            payload.state === 'Settled') {
          sawTrade = true;
        }
        if (pending.subject === positionTopic &&
            payload &&
            payload.security === security &&
            Number.isFinite(Number(payload.quantity))) {
          sawPosition = true;
        }
        maybeDone();
      } catch (err) {
        // Ignore unrelated / non-JSON payloads.
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
  if (submitted) {
    return;
  }
  submitted = true;
  const response = await fetch(`${tradeServiceUrl}/trade/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      security,
      quantity: qty,
      accountId,
      side: 'Buy',
    }),
  });
  if (response.status !== 200) {
    const body = await response.text();
    fail(`expected 200 from trade submit, got ${response.status}; body=${body}`);
  }
}

const timer = setTimeout(() => {
  fail(`timed out waiting for realtime account updates (trade=${sawTrade}, position=${sawPosition})`);
}, timeoutMs);

const ws = new WebSocket(wsUrl);
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
    fail(`trade submit failed: ${err.message}`);
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
  fail(`websocket error while connected to ${wsUrl}`);
};

process.on('exit', () => {
  clearTimeout(timer);
  try { ws.close(); } catch (_) {}
});
NODE

echo "[check] ingress trade-service unknown ticker validation"
status_code="$(curl -sS -o /tmp/traderx-state-007-trade.out -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d '{"security":"NOTREAL","quantity":1,"accountId":22214,"side":"Buy"}' \
  "${INGRESS_URL}/trade-service/trade")"
cat /tmp/traderx-state-007-trade.out
echo
rm -f /tmp/traderx-state-007-trade.out
if [[ "${status_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker through ingress, got ${status_code}"
  exit 1
fi

echo "[check] baseline component smoke suite in state 007 runtime"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085"
"${REPO_ROOT}/scripts/test-database-overlay.sh" "18082" "18083" "http://localhost:18084/" "http://localhost:18088/account/22214"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 007 messaging-nats runtime smoke tests passed"
