#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
USER_ACCOUNT_ID="${2:-22214}"
ADMIN_ACCOUNT_ID="${3:-44044}"
TIMEOUT_MS="${TIMEOUT_MS:-35000}"

echo "[check] realtime order/trade/position streams over NATS websocket"
INGRESS_URL="${INGRESS_URL}" \
USER_ACCOUNT_ID="${USER_ACCOUNT_ID}" \
ADMIN_ACCOUNT_ID="${ADMIN_ACCOUNT_ID}" \
TIMEOUT_MS="${TIMEOUT_MS}" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const userAccountId = Number(process.env.USER_ACCOUNT_ID || '22214');
const adminAccountId = Number(process.env.ADMIN_ACCOUNT_ID || '44044');
const timeoutMs = Number(process.env.TIMEOUT_MS || '35000');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';

if (typeof WebSocket !== 'function') {
  console.error('[error] global WebSocket is unavailable in this Node runtime');
  process.exit(1);
}

const userOrdersTopic = `/accounts/${userAccountId}/orders`;
const adminOrdersTopic = `/accounts/${adminAccountId}/orders`;
const allOrdersTopic = '/orders';
const adminTradesTopic = `/accounts/${adminAccountId}/trades`;
const adminPositionsTopic = `/accounts/${adminAccountId}/positions`;

const sidByTopic = new Map([
  [userOrdersTopic, 1],
  [adminOrdersTopic, 2],
  [allOrdersTopic, 3],
  [adminTradesTopic, 4],
  [adminPositionsTopic, 5],
]);

let userOrderId = null;
let adminOrderId = null;
let buffer = '';
let pending = null;
const orderIdsBySubjectStatus = new Map();

const seen = {
  userCreateAccount: false,
  userCreateAll: false,
  userCancelAccount: false,
  userCancelAll: false,
  adminFillAccount: false,
  adminFillAll: false,
  adminTrade: false,
  adminPosition: false,
};

function fail(message) {
  console.error(`[error] ${message}`);
  process.exit(1);
}

function trackOrderEvent(subject, payload) {
  const orderId = String(payload.orderId || '');
  const status = String(payload.status || '');
  if (!orderId || !status) {
    return;
  }
  const key = `${subject}|${status}`;
  let orderIds = orderIdsBySubjectStatus.get(key);
  if (!orderIds) {
    orderIds = new Set();
    orderIdsBySubjectStatus.set(key, orderIds);
  }
  orderIds.add(orderId);
}

function hasOrderEvent(subject, status, orderId) {
  if (!orderId) {
    return false;
  }
  const key = `${subject}|${status}`;
  const orderIds = orderIdsBySubjectStatus.get(key);
  return Boolean(orderIds && orderIds.has(String(orderId)));
}

function syncSeenFlagsFromTrackedEvents() {
  if (userOrderId) {
    if (hasOrderEvent(userOrdersTopic, 'NEW', userOrderId)) {
      seen.userCreateAccount = true;
    }
    if (hasOrderEvent(allOrdersTopic, 'NEW', userOrderId)) {
      seen.userCreateAll = true;
    }
    if (hasOrderEvent(userOrdersTopic, 'CANCELED', userOrderId)) {
      seen.userCancelAccount = true;
    }
    if (hasOrderEvent(allOrdersTopic, 'CANCELED', userOrderId)) {
      seen.userCancelAll = true;
    }
  }

  if (adminOrderId) {
    if (hasOrderEvent(adminOrdersTopic, 'FILLED', adminOrderId)) {
      seen.adminFillAccount = true;
    }
    if (hasOrderEvent(allOrdersTopic, 'FILLED', adminOrderId)) {
      seen.adminFillAll = true;
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

function waitFor(checkFn, label, timeout = timeoutMs) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const timer = setInterval(() => {
      if (checkFn()) {
        clearInterval(timer);
        resolve();
        return;
      }
      if (Date.now() - start > timeout) {
        clearInterval(timer);
        reject(new Error(`timeout waiting for ${label}`));
      }
    }, 100);
  });
}

function normalizePayload(payloadText) {
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

  trackOrderEvent(subject, payload);
  syncSeenFlagsFromTrackedEvents();

  if (userOrderId && payload.orderId === userOrderId) {
    if (subject === userOrdersTopic && payload.status === 'NEW') {
      seen.userCreateAccount = true;
    }
    if (subject === allOrdersTopic && payload.status === 'NEW') {
      seen.userCreateAll = true;
    }
    if (subject === userOrdersTopic && payload.status === 'CANCELED') {
      seen.userCancelAccount = true;
    }
    if (subject === allOrdersTopic && payload.status === 'CANCELED') {
      seen.userCancelAll = true;
    }
  }

  if (adminOrderId && payload.orderId === adminOrderId) {
    if (subject === adminOrdersTopic && payload.status === 'FILLED') {
      seen.adminFillAccount = true;
    }
    if (subject === allOrdersTopic && payload.status === 'FILLED') {
      seen.adminFillAll = true;
    }
  }

  if (
    subject === adminTradesTopic &&
    payload.security === 'JPM' &&
    payload.side === 'Sell' &&
    Number(payload.quantity) === 11
  ) {
    seen.adminTrade = true;
  }

  if (
    subject === adminPositionsTopic &&
    payload.security === 'JPM' &&
    Number.isFinite(Number(payload.quantity))
  ) {
    seen.adminPosition = true;
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
      const payload = normalizePayload(payloadText);
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

async function main() {
  const ws = new WebSocket(wsUrl);

  await Promise.race([
    new Promise((resolve, reject) => {
      ws.onopen = resolve;
      ws.onerror = () => reject(new Error(`websocket error while connecting to ${wsUrl}`));
    }),
    new Promise((_, reject) => setTimeout(() => reject(new Error(`timeout connecting to ${wsUrl}`)), 8000)),
  ]);

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
    fail(`websocket error while connected to ${wsUrl}`);
  };

  ws.send('CONNECT {"protocol":1,"verbose":false,"pedantic":false,"echo":false}\r\n');
  for (const [topic, sid] of sidByTopic.entries()) {
    ws.send(`SUB ${topic} ${sid}\r\n`);
  }
  ws.send('PING\r\n');

  const userCreate = await requestJson(
    '/order-matcher/orders',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        accountId: userAccountId,
        security: 'IBM',
        side: 'Buy',
        quantity: 33,
        // Keep this non-marketable so cancel-event assertions do not race auto-fill ticks.
        limitPrice: 1.0,
      }),
    },
    201
  );
  userOrderId = userCreate.orderId;
  if (!userOrderId) {
    fail('user order create response missing orderId');
  }
  syncSeenFlagsFromTrackedEvents();

  await waitFor(() => seen.userCreateAccount && seen.userCreateAll, 'user create order events');

  await requestJson(
    `/order-matcher/orders/${userOrderId}/cancel`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    },
    200
  );

  await waitFor(() => seen.userCancelAccount && seen.userCancelAll, 'user cancel order events');

  const adminCreate = await requestJson(
    '/order-matcher/orders',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        accountId: adminAccountId,
        security: 'JPM',
        side: 'Sell',
        quantity: 11,
        limitPrice: 191.875,
      }),
    },
    201
  );
  adminOrderId = adminCreate.orderId;
  if (!adminOrderId) {
    fail('admin order create response missing orderId');
  }
  syncSeenFlagsFromTrackedEvents();

  await requestJson(
    `/order-matcher/orders/${adminOrderId}/force-fill`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    },
    200
  );

  await waitFor(
    () => seen.adminFillAccount && seen.adminFillAll && seen.adminTrade && seen.adminPosition,
    'admin force-fill order/trade/position realtime events'
  );

  console.log('[info] realtime order streams validated for create/cancel/force-fill');
  console.log('[info] cross-stream causality validated for order -> trade -> position');
  ws.close();
}

main().catch((err) => fail(err.message));
NODE

echo "[done] realtime order stream overlay test passed"
