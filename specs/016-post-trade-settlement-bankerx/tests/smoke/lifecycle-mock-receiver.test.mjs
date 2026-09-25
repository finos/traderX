#!/usr/bin/env node
// Lifecycle smoke tests for spec 016 (child of 014) — plain node, no deps.
// Runs the SAME provider-neutral lifecycle module the mock receiver page uses,
// so demo and test share one implementation. Run: node tests/smoke/lifecycle-mock-receiver.test.mjs
import { strict as assert } from 'node:assert';
import { PaymentReceiver, validatePaymentContext, toSettlementStatusContext, STATUS } from '../../generation/mock-receiver/payment-lifecycle.mjs';

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let gates = 0;
function gate(name, fn) {
  return Promise.resolve()
    .then(fn)
    .then(() => { console.log(`[ok] ${name}`); gates += 1; })
    .catch((error) => { console.error(`[fail] ${name}: ${error.message}`); process.exitCode = 1; });
}

const validContext = {
  type: 'fdc3.paymentContext',
  id: { UETR: '6f1e0e2a-1b3f-4c8d-9a2b-3c4d5e6f7a8b' },
  amount: 1000,
  currency: 'USD',
  pair: 'USD/KES',
  rate: 129.5,
  debtor: { name: 'TraderX Institutional Execution Desk', account: 'traderx-desk-01' },
  creditor: { name: 'BankerX Institutional Liquidity Desk', account: 'bankerx-settler-01' },
  networkRouting: { rail: 'Mock Rail', channel: 'global', uetr: '6f1e0e2a-1b3f-4c8d-9a2b-3c4d5e6f7a8b' }
};

await gate('A: valid paymentContext passes validation', async () => {
  const verdict = validatePaymentContext(validContext);
  assert.equal(verdict.valid, true, JSON.stringify(verdict));
});

await gate('B: UETR must be RFC 4122 UUIDv4', async () => {
  const bad = { ...validContext, id: { UETR: 'UETR-123' } };
  assert.equal(validatePaymentContext(bad).valid, false);
  assert.equal(validatePaymentContext(bad).reason, 'uetr_not_rfc4122_uuidv4');
  assert.match(validContext.id.UETR, UUID_V4, 'fixture UETR itself must be UUIDv4');
});

await gate('C: wrong context type is rejected', async () => {
  const bad = { ...validContext, type: 'fdc3.instrument' };
  assert.equal(validatePaymentContext(bad).reason, 'wrong_context_type');
});

await gate('D: malformed payloads rejected field-by-field', async () => {
  for (const [mutate, reason] of [
    [(c) => ({ ...c, amount: -1 }), 'amount_invalid'],
    [(c) => ({ ...c, currency: 'USDX' }), 'currency_not_iso4217_alpha3'],
    [(c) => ({ ...c, pair: 'USD-KES' }), 'pair_not_canonical'],
    [(c) => ({ ...c, rate: 0 }), 'rate_invalid'],
    [(c) => ({ ...c, debtor: { name: '', account: 'x' } }), 'debtor_incomplete'],
    [(c) => ({ ...c, creditor: { name: 'x' } }), 'creditor_incomplete'],
    [(c) => { const { networkRouting, ...rest } = c; return rest; }, 'networkRouting_missing']
  ]) {
    const verdict = validatePaymentContext(mutate(validContext));
    assert.equal(verdict.valid, false, `expected ${reason}, got ${JSON.stringify(verdict)}`);
    assert.equal(verdict.reason, reason);
  }
});

await gate('E: happy path settles Acsc and broadcasts status context', async () => {
  const receiver = new PaymentReceiver();
  const record = await receiver.receive(validContext);
  assert.equal(record.status, STATUS.ACCEPTED);
  const status = toSettlementStatusContext(record);
  assert.equal(status.type, 'synaptic.settlementStatus');
  assert.equal(status.id.UETR, validContext.id.UETR);
  assert.equal(status.traderxSettlementStatus, 'Acsc');
});

await gate('F: duplicate dispatch replays the FIRST outcome', async () => {
  const receiver = new PaymentReceiver();
  await receiver.receive(validContext);
  const replay = await receiver.receive(validContext);
  assert.equal(replay.duplicate, true);
  assert.equal(replay.status, 'Acsc');
  const count = receiver.settlements.get(validContext.id.UETR);
  assert.equal(count, receiver.settlements.get(validContext.id.UETR));
  const eventsForUetr = receiver.events.filter((e) => e.uetr === validContext.id.UETR && !e.duplicate);
  assert.equal(eventsForUetr.length, 1, 'exactly one settlement record per UETR');
});

await gate('G: honest rejection is recorded, not silently dropped', async () => {
  const receiver = new PaymentReceiver({
    rejectedReasons: [{ predicate: () => true, detail: 'sanctions: counterparty screened out' }]
  });
  const record = await receiver.receive(validContext);
  assert.equal(record.status, 'Rjct');
  assert.equal(record.detail, 'sanctions: counterparty screened out');
  assert.equal(receiver.settlements.get(validContext.id.UETR).status, 'Rjct');
});

await gate('H: schema-invalid context is rejected with reason (honest outcome)', async () => {
  const receiver = new PaymentReceiver();
  const record = await receiver.receive({ type: 'fdc3.paymentContext', id: {} });
  assert.equal(record.status, 'Rjct');
  assert.match(record.detail, /schema:/);
});

await gate('I: rail failure falls back to Pndg, never a fake Acsc', async () => {
  const receiver = new PaymentReceiver({ rails: [{ id: 'Broken Rail', settle: async () => ({ status: 'boom' }) }] });
  const record = await receiver.receive(validContext);
  assert.equal(record.status, 'Pndg');
});

await gate('J: status context carries UETR correlation fields', async () => {
  const status = toSettlementStatusContext({ uetr: validContext.id.UETR, status: 'Rjct', rail: 'Mock Rail', detail: 'x' });
  assert.equal(status.traderxSettlementStatus, 'Rjct');
  assert.equal(status.traderxRail, 'Mock Rail');
  assert.equal(status.id.UETR, validContext.id.UETR);
});

if (process.exitCode) {
  console.error(`[fail] lifecycle smoke failed at gate ${gates}`);
} else {
  console.log(`[ok] lifecycle mock-receiver smoke passed (${gates} gates)`);
}