// Post-trade settlement lifecycle — provider-neutral, dependency-free module.
// Used by the local mock receiver page AND by the lifecycle smoke tests, so the
// request-to-outcome lesson is identical in demo and test contexts.

/** ISO 20022 pacs.002 status codes the lifecycle demonstrates. */
export const STATUS = {
    ACCEPTED: 'Acsc', // settlement completed
    PENDING: 'Pndg', // dispatched, outcome pending
    REJECTED: 'Rjct' // honestly rejected (schema, sanctions, or solvency)
};

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Validates an fdc3.paymentContext payload (CBPR+ field-level checks).
 * Returns { valid: true, context } or { valid: false, reason }.
 */
export function validatePaymentContext(context) {
    if (!context || typeof context !== 'object') {
        return { valid: false, reason: 'not_an_object' };
    }
    if (context.type !== 'fdc3.paymentContext') {
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
    if (typeof context.currency !== 'string' || context.currency.trim().length !== 3) {
        return { valid: false, reason: 'currency_not_iso4217_alpha3' };
    }
    if (typeof context.pair !== 'string' || !context.pair.includes('/')) {
        return { valid: false, reason: 'pair_not_canonical' };
    }
    if (!Number.isFinite(Number(context.rate)) || Number(context.rate) <= 0) {
        return { valid: false, reason: 'rate_invalid' };
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
    constructor(options = {}) {
        // rails: ordered list of settlement handlers; each handler receives
        // (context) and returns { status, txHash?, detail? } synchronously or
        // via Promise. Default: single "mock" rail that always settles.
        this.rails = options.rails ?? [{ id: 'Mock Rail', settle: async () => ({ status: STATUS.ACCEPTED }) }];
        this.rejectedReasons = options.rejectedReasons ?? [];
        this.settlements = new Map(); // uetr -> { status, txHash?, rail }
        this.events = [];
    }

    /**
     * Handles an inbound StartPayment context. Returns the pacs.002-style
     * status event to broadcast, or a rejection. A UETR that was already
     * processed replays its FIRST outcome — it is never settled twice.
     */
    async receive(context) {
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
            const outcome = await rail.settle(context);
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