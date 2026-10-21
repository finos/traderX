// Payment-instruction mapping tests (Spec 016) — plain node, no deps.
//
// Regression context (DovOps consolidated review, #470 open items): an equity
// trade (BAC) used to produce a payment instruction with currency 'BAC',
// pair 'BAC/KES' and amount 14020.964999999998 — an instrument symbol passed
// off as an ISO 4217 currency and an unrounded float on the wire. These tests
// pin the cash-leg mapping, the rounding, the party direction and the
// receiver-side rejection of invalid instructions.
//
// Run: node tests/smoke/payment-instruction.test.mjs
import { strict as assert } from 'node:assert';
import {
    buildPaymentInstruction,
    parseSettlementInstrument,
    roundMinorUnit,
    VENUE_QUOTE_CURRENCY
} from '../../generation/payment-instruction.mjs';
import { validatePaymentContext } from '../../generation/mock-receiver/payment-lifecycle.mjs';

let gates = 0;
function gate(name, fn) {
    return Promise.resolve()
        .then(fn)
        .then(() => { console.log(`[ok] ${name}`); gates += 1; })
        .catch((error) => { console.error(`[fail] ${name}: ${error.message}`); process.exitCode = 1; });
}

const DESKS = {
    executionDesk: { name: 'TraderX Institutional Execution Desk', account: 'traderx-desk-01' },
    counterpartyDesk: { name: 'BankerX Institutional Liquidity Desk', account: 'bankerx-settler-01' }
};
const UETR = '6f1e0e2a-1b3f-4c8d-9a2b-3c4d5e6f7a8b';
const routing = { rail: 'Mock Rail', channel: 'global', uetr: UETR };

// The exact defect case: BAC equity, 1000 shares @ 14.020965 → 14020.964999999998 raw.
const BAC_TRADE = { security: 'BAC', quantity: 1000, price: 14.020965, side: 'Buy' };

await gate('P1: equity trade maps to venue cash currency KES, no pair/rate', async () => {
    const r = buildPaymentInstruction(BAC_TRADE, DESKS);
    assert.ok(r.ok, 'instruction must be buildable');
    assert.equal(r.instruction.currency, 'KES');
    assert.equal(VENUE_QUOTE_CURRENCY, 'KES');
    assert.equal(r.instruction.pair, null);
    assert.equal(r.instruction.rate, null);
});

await gate('P2: equity notional is minor-unit rounded (no float drift on the wire)', async () => {
    const r = buildPaymentInstruction(BAC_TRADE, DESKS);
    // The true decimal product is 14020.965 exactly; the mapper's epsilon
    // correction recovers it from the float drift (14020.964999999998) and
    // rounds half-up — so the wire carries 14020.97, never the drifted float.
    assert.equal(r.instruction.amount, 14020.97);
    assert.ok(!String(r.instruction.amount).includes('99999'), 'float drift must not survive');
});

await gate('P3: equity instruction passes the receiver validator (pair/rate omitted cleanly)', async () => {
    const r = buildPaymentInstruction(BAC_TRADE, DESKS);
    const verdict = validatePaymentContext({
        type: 'fdc3.payment',
        id: { UETR },
        ...r.instruction,
        networkRouting: routing
    });
    assert.ok(verdict.valid, `equity instruction must validate — got ${verdict.reason}`);
});

await gate('P4: FX pair trade maps to its base leg at the fill rate', async () => {
    const r = buildPaymentInstruction(
        { security: 'USD/KES', quantity: 1000, price: 129.42, side: 'Buy' }, DESKS);
    assert.ok(r.ok);
    assert.equal(r.instruction.currency, 'USD');
    assert.equal(r.instruction.pair, 'USD/KES');
    assert.equal(r.instruction.rate, 129.42);
    assert.equal(r.instruction.amount, 1000);
});

await gate('P5: party direction follows the trade side (buyer owes the cash)', async () => {
    const buy = buildPaymentInstruction(BAC_TRADE, DESKS);
    const sell = buildPaymentInstruction({ ...BAC_TRADE, side: 'Sell' }, DESKS);
    assert.deepEqual(buy.instruction.debtor, DESKS.executionDesk);
    assert.deepEqual(buy.instruction.creditor, DESKS.counterpartyDesk);
    assert.deepEqual(sell.instruction.debtor, DESKS.counterpartyDesk);
    assert.deepEqual(sell.instruction.creditor, DESKS.executionDesk);
});

await gate('P6: instrument classification — currency-shaped but non-existent codes are not instruments', async () => {
    assert.deepEqual(parseSettlementInstrument('BAC'), { kind: 'equity', ticker: 'BAC' });
    assert.equal(parseSettlementInstrument('BAC').kind, 'equity');
    assert.equal(parseSettlementInstrument('USD/KES').kind, 'fx');
    // A bare currency code is not a tradeable instrument in this blotter.
    assert.equal(parseSettlementInstrument('USD').kind, 'invalid');
    // Pair with a leg that is not a real currency code.
    assert.equal(parseSettlementInstrument('BAC/KES').kind, 'invalid');
    assert.equal(parseSettlementInstrument('USD-KES').kind, 'invalid');
    assert.equal(parseSettlementInstrument('').kind, 'invalid');
    assert.equal(parseSettlementInstrument(null).kind, 'invalid');
});

await gate('P7: receiver validator rejects an equity symbol as currency (the defect shape)', async () => {
    const verdict = validatePaymentContext({
        type: 'fdc3.payment',
        id: { UETR: '9d2b6c3e-8f14-4a7b-b2c1-5d6e7f8a9b0c' },
        amount: 14020.964999999998,
        currency: 'BAC',
        pair: 'BAC/KES',
        rate: 14.020965,
        debtor: DESKS.executionDesk,
        creditor: DESKS.counterpartyDesk,
        networkRouting: routing
    });
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'currency_not_iso4217', `'BAC' must be refused as a currency code`);
});

await gate('P8: receiver validator rejects lone pair or lone rate (coupled FX frame)', async () => {
    const base = {
        type: 'fdc3.payment',
        id: { UETR },
        amount: 1000,
        currency: 'USD',
        debtor: DESKS.executionDesk,
        creditor: DESKS.counterpartyDesk,
        networkRouting: routing
    };
    assert.deepEqual(validatePaymentContext({ ...base, pair: 'USD/KES' }),
        { valid: false, reason: 'pair_without_rate' });
    assert.deepEqual(validatePaymentContext({ ...base, rate: 129.42 }),
        { valid: false, reason: 'rate_without_pair' });
    assert.ok(validatePaymentContext(base).valid, 'neither field is a valid cash transfer');
});

await gate('P9: receiver validator rejects non-currency pair legs', async () => {
    const verdict = validatePaymentContext({
        type: 'fdc3.payment',
        id: { UETR },
        amount: 1000,
        currency: 'KES',
        pair: 'BAC/KES',
        rate: 14.02,
        debtor: DESKS.executionDesk,
        creditor: DESKS.counterpartyDesk,
        networkRouting: routing
    });
    assert.equal(verdict.valid, false);
    assert.equal(verdict.reason, 'fx_leg_not_iso4217');
});

await gate('P10: unsettleable securities are refused by the mapping, never dispatched', async () => {
    for (const security of ['USD', 'BAC/KES', 'USD-KES', 'TOOLONGTICKER', '', null]) {
        const r = buildPaymentInstruction({ security, quantity: 10, price: 1 }, DESKS);
        assert.equal(r.ok, false, `${JSON.stringify(security)} must be refused`);
        assert.ok(r.reason, 'refusal names a reason');
    }
});

await gate('P11: roundMinorUnit rounding helper — float drift is recovered, half-up', async () => {
    // 1000 × 14.020965 = 14020.965 exactly in decimal; the binary-float
    // product drifts to 14020.964999999998 and the correction recovers the
    // true decimal value before rounding.
    assert.equal(roundMinorUnit(14020.964999999998), 14020.97);
    assert.equal(roundMinorUnit(14020.965), 14020.97);
    assert.equal(roundMinorUnit(14020.964), 14020.96);
    assert.equal(roundMinorUnit(0.1 + 0.2), 0.3);
    assert.equal(roundMinorUnit(1), 1);
});

console.log(`== payment-instruction: ${gates}/11 gates passed`);
if (process.exitCode) {
    console.error('== RED');
} else {
    console.log('== GREEN');
}