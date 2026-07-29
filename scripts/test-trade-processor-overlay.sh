#!/usr/bin/env bash
set -euo pipefail

ORIGIN="${1:-http://localhost:18093}"
PROCESSOR_URL="${2:-http://localhost:18091}"
POSITION_URL="${3:-http://localhost:18090}"
TRADE_FEED_URL="${4:-http://localhost:18086}"
WAIT_ATTEMPTS="${WAIT_ATTEMPTS:-60}"
WAIT_SLEEP_SECONDS="${WAIT_SLEEP_SECONDS:-1}"

ACCOUNT_ID=22214
QTY=7
SECURITY="TS$((RANDOM % 9000 + 1000))$(date +%s)"
SECURITY="${SECURITY:0:15}"
SMOKE_ID="tp-$(date +%s)-$RANDOM"

echo "[check] trade-processor docs endpoint"
curl -sS -i "${PROCESSOR_URL}/" | sed -n '1,20p'

echo "[check] CORS preflight for trade-processor order endpoint"
headers="$(
  curl -sS -i -X OPTIONS \
    -H "Origin: ${ORIGIN}" \
    -H "Access-Control-Request-Method: POST" \
    "${PROCESSOR_URL}/tradeservice/order" | sed -n '1,30p'
)"
echo "${headers}"

cors_header="$(printf '%s\n' "${headers}" | awk -F': ' 'tolower($1)=="access-control-allow-origin" {print $2}' | tr -d '\r' || true)"
if [[ -z "${cors_header}" ]]; then
  echo "[error] missing Access-Control-Allow-Origin header on trade-processor"
  exit 1
fi

if [[ "${cors_header}" != "*" && "${cors_header}" != "${ORIGIN}" ]]; then
  echo "[error] unexpected Access-Control-Allow-Origin value: ${cors_header}"
  exit 1
fi

echo "[check] publish TradeOrder through trade-feed and verify account topic updates"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SOCKET_IO_CLIENT_PATH="$("${REPO_ROOT}/scripts/lib/resolve-socketio-client-path.sh")"

TRADE_FEED_URL="${TRADE_FEED_URL}" \
ACCOUNT_ID="${ACCOUNT_ID}" \
SECURITY="${SECURITY}" \
QTY="${QTY}" \
SMOKE_ID="${SMOKE_ID}" \
SOCKET_IO_CLIENT_PATH="${SOCKET_IO_CLIENT_PATH:-${DEFAULT_SOCKET_IO_CLIENT_PATH}}" node <<'NODE'
const baseUrl = process.env.TRADE_FEED_URL || 'http://localhost:18086';
const accountId = Number(process.env.ACCOUNT_ID || '22214');
const security = process.env.SECURITY;
const qty = Number(process.env.QTY || '7');
const smokeId = process.env.SMOKE_ID;
const clientModulePath = process.env.SOCKET_IO_CLIENT_PATH;

let createClient;
try {
  createClient = require(clientModulePath).io;
} catch (err) {
  createClient = require('socket.io-client').io;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(`timeout: ${label}`)), ms))
  ]);
}

function waitForConnect(client, label) {
  return withTimeout(new Promise((resolve, reject) => {
    client.on('connect', resolve);
    client.on('connect_error', (err) => reject(new Error(`${label} connect_error: ${err.message}`)));
  }), 8000, `${label} connect`);
}

async function main() {
  const inboundTopic = '/trades';
  const tradeTopic = `/accounts/${accountId}/trades`;
  const positionTopic = `/accounts/${accountId}/positions`;

  let sawTradeUpdate = false;
  let sawPositionUpdate = false;

  const subscriber = createClient(baseUrl, { transports: ['websocket'] });
  const publisher = createClient(baseUrl, { transports: ['websocket'] });

  try {
    await Promise.all([
      waitForConnect(subscriber, 'subscriber'),
      waitForConnect(publisher, 'publisher')
    ]);

    subscriber.on('publish', (message) => {
      if (!message || !message.topic || !message.payload) {
        return;
      }

      if (
        message.topic === tradeTopic &&
        message.payload.security === security &&
        Number(message.payload.quantity) === qty &&
        message.payload.state === 'Settled'
      ) {
        sawTradeUpdate = true;
      }

      if (
        message.topic === positionTopic &&
        message.payload.security === security &&
        Number(message.payload.quantity) === qty
      ) {
        sawPositionUpdate = true;
      }
    });

    subscriber.emit('subscribe', tradeTopic);
    subscriber.emit('subscribe', positionTopic);
    await wait(250);

    publisher.emit('publish', {
      topic: inboundTopic,
      type: 'TradeOrder',
      payload: {
        id: smokeId,
        accountId,
        security,
        side: 'Buy',
        quantity: qty
      }
    });

    await withTimeout(new Promise((resolve) => {
      const poll = setInterval(() => {
        if (sawTradeUpdate && sawPositionUpdate) {
          clearInterval(poll);
          resolve();
        }
      }, 100);
    }), 12000, 'trade-processor publish flow');

    console.log('[info] trade-feed publish -> trade-processor -> account topics flow passed');
  } finally {
    subscriber.disconnect();
    publisher.disconnect();
  }
}

main().catch((err) => {
  console.error(`[error] ${err.message}`);
  process.exit(1);
});
NODE

echo "[check] processed trade persisted and visible via position-service"
found_trade=0
for _ in $(seq 1 "${WAIT_ATTEMPTS}"); do
  trades_json="$(curl -sS "${POSITION_URL}/trades/${ACCOUNT_ID}")"
  if echo "${trades_json}" | jq -e --arg sec "${SECURITY}" --argjson qty "${QTY}" 'map(select(.security == $sec and .quantity == $qty and .state == "Settled")) | length > 0' >/dev/null; then
    found_trade=1
    break
  fi
  sleep "${WAIT_SLEEP_SECONDS}"
done
if [[ "${found_trade}" != "1" ]]; then
  echo "[error] expected settled trade for security ${SECURITY} via position-service"
  exit 1
fi

found_position=0
for _ in $(seq 1 "${WAIT_ATTEMPTS}"); do
  positions_json="$(curl -sS "${POSITION_URL}/positions/${ACCOUNT_ID}")"
  if echo "${positions_json}" | jq -e --arg sec "${SECURITY}" --argjson qty "${QTY}" 'map(select(.security == $sec and .quantity == $qty)) | length > 0' >/dev/null; then
    found_position=1
    break
  fi
  sleep "${WAIT_SLEEP_SECONDS}"
done
if [[ "${found_position}" != "1" ]]; then
  echo "[error] expected position update for security ${SECURITY} via position-service"
  exit 1
fi

echo "[done] trade-processor overlay smoke tests passed"
