// Post-trade settlement lifecycle — provider-neutral, dependency-free module.
// Used by the local mock receiver page AND by the lifecycle smoke tests, so the
// request-to-outcome lesson is identical in demo and test contexts. The
// traderx-blotter-web copy is a vendored mirror of this file — keep in sync.

// The ISO 4217 admission set comes from the settlement-instruction mapping
// module (one definition of "a real currency code" — see ../payment-instruction.mjs).
import { ISO4217_CURRENCIES } from '../payment-instruction.mjs';

/** ISO 20022 pacs.002 status codes the lifecycle demonstrates. */
export const STATUS = {
    ACCEPTED: 'Acsc', // settlement completed
    PENDING: 'Pndg', // dispatched, outcome pending
    REJECTED: 'Rjct' // honestly rejected (schema, sanctions, or solvency)
};

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
// Canonical FX pair: both legs must be REAL ISO 4217 codes — 'BAC/KES' is
// alpha-3-shaped but BAC is an instrument symbol, not a currency, and this
// validator is the boundary that refuses it.
const CANONICAL_PAIR = /^[A-Z]{3}\/[A-Z]{3}$/i;

/**
 * Validates an fdc3.payment payload (FINOS PR #2204 name; legacy Spec 016
 * "fdc3.paymentContext" accepted for backward compatibility).
 * Returns { valid: true, context } or { valid: false, reason }.
 */
export function validatePaymentContext(context) {
    if (!context || typeof context !== 'object') {
        return { valid: false, reason: 'not_an_object' };
    }
    const ACCEPTED = ['fdc3.payment', 'fdc3.paymentContext'];
    if (!ACCEPTED.includes(context.type)) {
        return { valid: false, reason: 'wrong_context_type' };
    }
    const uetr = context?.id?.UETR;
    if (typeof uetr !== 'string' || !UUID_V4.test(uetr)) {
        return { valid: false, reason: 'uetr_not_rfc4122_uuidv4' };
    }
    const amount = Number(context.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
        return { valid: false, reason: 'amount_invalid' };
    }
    const currency = context.currency;
    if (typeof currency !== 'string' || currency.length !== 3 || !ISO4217_CURRENCIES.has(currency.toUpperCase())) {
        return { valid: false, reason: 'currency_not_iso4217' };
    }
    // pair/rate are a coupled OPTIONAL frame: present on FX cash legs (the
    // pair is the traded instrument and rate its fill), absent on same-currency
    // cash transfers (equity settlements carry no FX conversion, and inventing
    // a corridor/rate the blotter does not hold is fabrication). Strictly
    // coupled: neither half alone is a valid instruction.
    const pair = context.pair;
    const rate = context.rate;
    const hasPair = pair !== undefined && pair !== null;
    const hasRate = rate !== undefined && rate !== null;
    if (hasPair) {
        if (!hasRate) {
            return { valid: false, reason: 'pair_without_rate' };
        }
        if (!Number.isFinite(Number(rate)) || Number(rate) <= 0) {
            return { valid: false, reason: 'rate_invalid' };
        }
    }
    if (!hasPair && hasRate) {
        return { valid: false, reason: 'rate_without_pair' };
    }
    if (hasPair) {
        const p = String(pair);
        if (!CANONICAL_PAIR.test(p)) {
            return { valid: false, reason: 'pair_not_canonical' };
        }
        const [base, quote] = p.toUpperCase().split('/');
        if (!ISO4217_CURRENCIES.has(base) || !ISO4217_CURRENCIES.has(quote)) {
            return { valid: false, reason: 'fx_leg_not_iso4217' };
        }
    }
    for (const party of ['debtor', 'creditor']) {
        const p = context[party];
        if (!p || typeof p.name !== 'string' || !p.name.trim() || typeof p.account !== 'string' || !p.account.trim()) {
            return { valid: false, reason: `${party}_incomplete` };
        }
    }
    if (!context.networkRouting || typeof context.networkRouting !== 'object') {
        return { valid: false, reason: 'networkRouting_missing' };
    }
    return { valid: true, context };
}

/**
 * Receives and settles payments with duplicate-dispatch prevention.
 * One instance per receiving app session; state is in-memory only.
 */
export class PaymentReceiver {
    #inflight;
    constructor(options = {}) {
        // rails: ordered list of settlement handlers; each handler receives
        // (context) and returns { status, txHash?, detail? } synchronously or
        // via Promise. Default: single "mock" rail that always settles.
        this.rails = options.rails ?? [{ id: 'Mock Rail', settle: async () => ({ status: STATUS.ACCEPTED }) }];
        this.rejectedReasons = options.rejectedReasons ?? [];
        this.settlements = new Map(); // uetr -> { status, txHash?, rail }
        this.events = [];
        // Per-UETR in-flight serialization: two concurrent receives of the
        // same payment must not run the rails twice (the settlements check
        // alone only guards AFTER the first outcome lands).
        this.#inflight = new Map();
    }

    /**
     * Handles an inbound StartPayment context. Returns the pacs.002-style
     * status event to broadcast, or a rejection. A UETR that was already
     * processed replays its FIRST outcome — it is never settled twice.
     * A UETR currently in flight (two concurrent receives) does not run the
     * rails a second time: the second caller awaits the first one's outcome
     * and replays it, marked duplicate, exactly as a post-facto duplicate.
     */
    async receive(context) {
        const uetr = context?.id?.UETR;
        if (uetr && this.#inflight.has(uetr)) {
            const inFlight = this.#inflight.get(uetr);
            const first = await inFlight;
            return { ...first, duplicate: true };
        }
        const run = this.#receiveNow(context);
        if (!uetr) return run;
        this.#inflight.set(uetr, run);
        try {
            return await run;
        } finally {
            this.#inflight.delete(uetr);
        }
    }

    async #receiveNow(context) {
        const verdict = validatePaymentContext(context);
        if (!verdict.valid) {
            return this.#record(context?.id?.UETR ?? 'unknown', STATUS.REJECTED, null, `schema: ${verdict.reason}`);
        }
        const uetr = context.id.UETR;
        const existing = this.settlements.get(uetr);
        if (existing) {
            return { ...existing, duplicate: true };
        }
        const rejected = this.rejectedReasons.find((entry) => (typeof entry === 'function' ? entry(context) : entry?.predicate?.(context)));
        if (rejected) {
            return this.#record(uetr, STATUS.REJECTED, null, rejected.detail ?? 'honest rejection');
        }
        for (const rail of this.rails) {
            let outcome;
            try {
                outcome = await rail.settle(context);
            } catch (error) {
                // A rail that throws must never reject receive(): the caller
                // (the receiver page) broadcasts whatever this returns, and
                // "the rail crashed before a status" is honestly Pndg —
                // never a fake Acsc (lifecycle test gate I).
                return this.#record(uetr, STATUS.PENDING, rail.id ?? null, `rail error: ${error?.message ?? error}`);
            }
            if (outcome?.status === STATUS.ACCEPTED || outcome?.status === STATUS.REJECTED) {
                return this.#record(uetr, outcome.status, rail.id, outcome.detail, outcome.txHash);
            }
        }
        return this.#record(uetr, STATUS.PENDING, this.rails[0]?.id ?? null, 'no rail confirmed');
    }

    #record(uetr, status, rail, detail, txHash) {
        const record = { uetr, status, rail, detail: detail ?? null, txHash: txHash ?? null, duplicate: false };
        if (!this.settlements.has(uetr)) {
            this.settlements.set(uetr, record);
        }
        this.events.push(record);
        return record;
    }
}

/** Builds the synaptic.settlementStatus broadcast for a settlement record. */
export function toSettlementStatusContext(record) {
    return {
        type: 'synaptic.settlementStatus',
        id: { UETR: record.uetr },
        traderxSettlementStatus: record.status,
        traderxRail: record.rail ?? undefined,
        traderxTxHash: record.txHash ?? undefined
    };
}