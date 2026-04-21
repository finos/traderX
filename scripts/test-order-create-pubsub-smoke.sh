#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ACCOUNT_ID="${2:-22214}"
TIMEOUT_MS="${TIMEOUT_MS:-20000}"

echo "[check] order create emits realtime events on account + /orders topics"
INGRESS_URL="${INGRESS_URL}" \
ACCOUNT_ID="${ACCOUNT_ID}" \
TIMEOUT_MS="${TIMEOUT_MS}" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const accountId = Number(process.env.ACCOUNT_ID || '22214');
const timeoutMs = Number(process.env.TIMEOUT_MS || '20000');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';

if (typeof WebSocket !== 'function') {
  console.error('[error] global WebSocket is unavailable in this Node runtime');
  process.exit(1);
}

const accountOrdersTopic = `/accounts/${accountId}/orders`;
const allOrdersTopic = '/orders';

let expectedOrderId = null;
let seenAccountCreate = false;
let seenAllCreate = false;
const accountNewOrderIds = new Set();
const allNewOrderIds = new Set();
let buffer = '';
let pending = null;
let closed = false;
let settled = false;

function fail(message) {
  if (settled) {
    return;
  }
  settled = true;
  console.error(`[error] ${message}`);
  process.exit(1);
}

function pass(message) {
  if (settled) {
    return;
  }
  settled = true;
  console.log(`[info] ${message}`);
  process.exit(0);
}

function maybeDone() {
  if (expectedOrderId && seenAccountCreate && seenAllCreate) {
    pass(`order ${expectedOrderId} published on ${accountOrdersTopic} and ${allOrdersTopic}`);
  }
}

function parsePayload(payloadText) {
  try {
    const parsed = JSON.parse(payloadText);
    if (parsed && typeof parsed === 'object' && parsed.payload) {
      return parsed.payload;
    }
    return parsed;
  } catch (err) {
    return null;
  }
}

function handleMessage(subject, payload) {
  if (!payload || typeof payload !== 'object') {
    return;
  }

  const orderId = String(payload.orderId || '');
  if (!orderId || payload.status !== 'NEW') {
    return;
  }

  if (subject === accountOrdersTopic) {
    accountNewOrderIds.add(orderId);
  }
  if (subject === allOrdersTopic) {
    allNewOrderIds.add(orderId);
  }

  if (!expectedOrderId) {
    return;
  }

  if (orderId !== expectedOrderId) {
    return;
  }

  if (subject === accountOrdersTopic) {
    seenAccountCreate = true;
  }
  if (subject === allOrdersTopic) {
    seenAllCreate = true;
  }

  maybeDone();
}

function parseFrameChunk(chunk, ws) {
  buffer += chunk;

  while (true) {
    if (pending) {
      const needed = pending.bytes + 2;
      if (buffer.length < needed) {
        return;
      }
      const payloadText = buffer.slice(0, pending.bytes);
      buffer = buffer.slice(needed);
      const payload = parsePayload(payloadText);
      handleMessage(pending.subject, payload);
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

async function requestJson(path, options, expectedStatus) {
  const response = await fetch(`${ingressUrl}${path}`, options);
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch (err) {
    fail(`invalid JSON response for ${path}: ${text}`);
  }
  if (response.status !== expectedStatus) {
    fail(`expected ${expectedStatus} from ${path}, got ${response.status}; body=${text}`);
  }
  return body;
}

async function main() {
  const ws = new WebSocket(wsUrl);

  const connectTimer = setTimeout(() => {
    if (!closed) {
      fail(`timeout connecting to ${wsUrl}`);
    }
  }, 8000);

  ws.onopen = async () => {
    clearTimeout(connectTimer);

    ws.send('CONNECT {"protocol":1,"verbose":false,"pedantic":false,"echo":false}\r\n');
    ws.send(`SUB ${accountOrdersTopic} 1\r\n`);
    ws.send(`SUB ${allOrdersTopic} 2\r\n`);
    ws.send('PING\r\n');

    const uniqueQty = Math.floor(Math.random() * 1000) + 1;
    const createPayload = {
      accountId,
      security: 'IBM',
      side: 'Buy',
      quantity: uniqueQty,
      limitPrice: 188.125
    };

    const createOrder = await requestJson(
      '/order-matcher/orders',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(createPayload)
      },
      201
    );

    expectedOrderId = String(createOrder.orderId || '');
    if (!expectedOrderId) {
      fail('create order response missing orderId');
    }

    seenAccountCreate = accountNewOrderIds.has(expectedOrderId);
    seenAllCreate = allNewOrderIds.has(expectedOrderId);
    maybeDone();
  };

  ws.onmessage = async (event) => {
    try {
      if (typeof event.data === 'string') {
        parseFrameChunk(event.data, ws);
        return;
      }
      if (event.data instanceof Blob) {
        parseFrameChunk(await event.data.text(), ws);
        return;
      }
      if (event.data instanceof ArrayBuffer) {
        parseFrameChunk(new TextDecoder().decode(new Uint8Array(event.data)), ws);
        return;
      }
      if (ArrayBuffer.isView(event.data)) {
        parseFrameChunk(
          new TextDecoder().decode(
            new Uint8Array(event.data.buffer, event.data.byteOffset, event.data.byteLength)
          ),
          ws
        );
      }
    } catch (err) {
      fail(`failed parsing websocket frame: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  ws.onerror = () => {
    fail(`websocket error while connected to ${wsUrl}`);
  };

  ws.onclose = () => {
    closed = true;
    if (!settled) {
      fail('websocket closed before required events were observed');
    }
  };

  setTimeout(() => {
    if (!settled) {
      fail(`timeout waiting for NEW order publish on ${accountOrdersTopic} and ${allOrdersTopic}`);
    }
  }, timeoutMs);
}

main().catch((err) => fail(err instanceof Error ? err.message : String(err)));
NODE

echo "[done] order create realtime publish smoke passed"
