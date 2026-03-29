#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:18086}"

echo "[check] trade-feed root endpoint"
curl -sS -i "${BASE_URL}/" | sed -n '1,20p'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SOCKET_IO_CLIENT_PATH="${REPO_ROOT}/TraderSpec/codebase/target-generated/trade-feed/node_modules/socket.io-client"

echo "[check] publish/subscribe compatibility including legacy unsubscribe command"
BASE_URL="${BASE_URL}" SOCKET_IO_CLIENT_PATH="${SOCKET_IO_CLIENT_PATH:-${DEFAULT_SOCKET_IO_CLIENT_PATH}}" node <<'NODE'
const baseUrl = process.env.BASE_URL || 'http://localhost:18086';
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
  const topic = '/traderspec/smoke';
  const smokeId = `smoke-${Date.now()}`;
  let receivedCount = 0;

  const subscriber = createClient(baseUrl, { transports: ['websocket'] });
  const publisher = createClient(baseUrl, { transports: ['websocket'] });

  try {
    await Promise.all([
      waitForConnect(subscriber, 'subscriber'),
      waitForConnect(publisher, 'publisher')
    ]);

    subscriber.on('publish', (message) => {
      if (message && message.topic === topic && message.payload && message.payload.smokeId === smokeId) {
        receivedCount += 1;
      }
    });

    subscriber.emit('subscribe', topic);
    await wait(250);

    publisher.emit('publish', {
      topic,
      type: 'message',
      payload: {
        smokeId,
        phase: 1
      }
    });

    await withTimeout(new Promise((resolve) => {
      const poll = setInterval(() => {
        if (receivedCount >= 1) {
          clearInterval(poll);
          resolve();
        }
      }, 50);
    }), 6000, 'first publish delivery');

    subscriber.emit('unusbscribe', topic);
    await wait(250);

    publisher.emit('publish', {
      topic,
      type: 'message',
      payload: {
        smokeId,
        phase: 2
      }
    });

    await wait(900);
    if (receivedCount !== 1) {
      throw new Error(`expected exactly 1 received message after legacy unsubscribe, got ${receivedCount}`);
    }

    console.log('[info] socket publish/subscribe checks passed');
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

echo "[done] trade-feed overlay smoke tests passed"
