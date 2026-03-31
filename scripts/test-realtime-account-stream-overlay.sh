#!/usr/bin/env bash
set -euo pipefail

TRADE_SERVICE_URL="${1:-http://localhost:18092}"
TRADE_FEED_URL="${2:-http://localhost:18086}"
ACCOUNT_ID="${3:-22214}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SOCKET_IO_CLIENT_PATH="${REPO_ROOT}/generated/code/target-generated/trade-feed/node_modules/socket.io-client"

echo "[check] realtime account stream over Socket.IO after trade submit"
TRADE_SERVICE_URL="${TRADE_SERVICE_URL}" \
TRADE_FEED_URL="${TRADE_FEED_URL}" \
ACCOUNT_ID="${ACCOUNT_ID}" \
SOCKET_IO_CLIENT_PATH="${SOCKET_IO_CLIENT_PATH:-${DEFAULT_SOCKET_IO_CLIENT_PATH}}" node <<'NODE'
const tradeServiceUrl = process.env.TRADE_SERVICE_URL || 'http://localhost:18092';
const tradeFeedUrl = process.env.TRADE_FEED_URL || 'http://localhost:18086';
const accountId = Number(process.env.ACCOUNT_ID || '22214');
const clientModulePath = process.env.SOCKET_IO_CLIENT_PATH;
const security = 'IBM';
const qty = 8000 + Math.floor(Math.random() * 500);
const tradeTopic = `/accounts/${accountId}/trades`;
const positionTopic = `/accounts/${accountId}/positions`;
const timeoutMs = 20000;

let createClient;
try {
  createClient = require(clientModulePath).io;
} catch (err) {
  try {
    createClient = require('socket.io-client').io;
  } catch (inner) {
    console.error('[error] socket.io-client module not found');
    console.error('[hint] set SOCKET_IO_CLIENT_PATH to a socket.io-client install path');
    process.exit(1);
  }
}

function fail(message) {
  console.error(`[error] ${message}`);
  process.exit(1);
}

async function waitForConnect(client, label) {
  await Promise.race([
    new Promise((resolve, reject) => {
      client.on('connect', resolve);
      client.on('connect_error', (err) => reject(new Error(`${label} connect_error: ${err.message}`)));
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error(`timeout: ${label} connect`)), 8000)),
  ]);
}

async function main() {
  let sawTrade = false;
  let sawPosition = false;
  const subscriber = createClient(tradeFeedUrl, { transports: ['websocket'] });

  const done = () => {
    if (sawTrade && sawPosition) {
      console.log('[info] account trade/position realtime updates received via Socket.IO');
      subscriber.disconnect();
      process.exit(0);
    }
  };

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
      sawTrade = true;
    }
    if (
      message.topic === positionTopic &&
      message.payload.security === security &&
      Number(message.payload.quantity) === qty
    ) {
      sawPosition = true;
    }
    done();
  });

  await waitForConnect(subscriber, 'subscriber');
  subscriber.emit('subscribe', tradeTopic);
  subscriber.emit('subscribe', positionTopic);

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

  setTimeout(() => {
    fail(`timed out waiting for realtime account updates (trade=${sawTrade}, position=${sawPosition})`);
  }, timeoutMs);
}

main().catch((err) => fail(err.message));
NODE

echo "[done] realtime account stream overlay test passed"
