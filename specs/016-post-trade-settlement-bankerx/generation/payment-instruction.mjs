// Trade → payment-instruction mapping (Spec 016 cash-leg) — dependency-free.
//
// The defect this module fixes: the blotter sent `currency: trade.security`
// for every trade, so an equity order (BAC) produced a payment instruction
// with `currency: 'BAC'`, `pair: 'BAC/KES'` — an instrument symbol passed off
// as an ISO 4217 currency — and a floating-point notional
// (14020.964999999998). A payment instruction carries the trade's CASH
// obligation, not its instrument.
//
// Mapping rules (declared here, mirrored in the Angular overlay at
// generation/frontend-overrides/.../trade-blotter/payment-instruction.ts —
// keep the two in sync; the smoke tests govern the mjs SSOT):
//   1. FX pair security (`AAA/BBB`, both ISO 4217): the trade IS the cash
//      leg. currency = base leg, pair = the security, rate = the execution
//      fill price, amount = traded base-currency quantity (minor-unit
//      rounded).
//   2. Equity ticker (a non-currency symbol): the cash obligation is a
//      same-currency transfer of quantity × fill price in the venue quote
//      currency (KES — TraderX demo venue). pair/rate are OMITTED: no FX
//      conversion exists in the trade, and inventing one (rate, corridor)
//      would fabricate data the blotter does not have.
//   3. Anything else is not settleable and is rejected before dispatch.
//
// Parties follow the trade side: the buyer owes the cash on both an equity
// buy and a base-legged FX buy, so debtor = the executing desk on Buys and
// the counterparty desk on Sells.

/** Venue quote currency of the TraderX demo (securities are priced in KES). */
export const VENUE_QUOTE_CURRENCY = 'KES';

/**
 * ISO 4217 active currency codes the validator admits. A trade whose
 * security resolves to a code outside this set is not settleable — this is
 * what rejects `currency: 'BAC'` (alpha-3-shaped but not a currency) before
 * dispatch AND at the receiver. Curated list: the majors, the demo's African
 * corridor currencies, and the other widely settled codes. Not exhaustive
 * ISO membership — the settled surface is what the desk admits.
 */
export const ISO4217_CURRENCIES = new Set([
    'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN',
    'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL',
    'BSD', 'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY',
    'COP', 'CRC', 'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP',
    'ERN', 'ETB', 'EUR', 'FJD', 'FKP', 'GBP', 'GEL', 'GHS', 'GIP', 'GMD',
    'GNF', 'GTQ', 'GYD', 'HKD', 'HNL', 'HRK', 'HTG', 'HUF', 'IDR', 'ILS',
    'INR', 'IQD', 'IRR', 'ISK', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR',
    'KMF', 'KRW', 'KWD', 'KYD', 'KZT', 'LAK', 'LBP', 'LKR', 'LRD', 'LSL',
    'LYD', 'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR',
    'MVR', 'MWK', 'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NOK', 'NPR', 'NZD',
    'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG', 'QAR', 'RON',
    'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP',
    'SLE', 'SOS', 'SRD', 'SSP', 'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS',
    'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD',
    'UYU', 'UZS', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XOF', 'XPF',
    'YER', 'ZAR', 'ZMW', 'ZWL'
]);

const FX_PAIR = /^[A-Z]{3}\/[A-Z]{3}$/;
// No hyphens: 'USD-KES' is malformed pair notation, not a ticker.
const EQUITY_TICKER = /^[A-Z][A-Z0-9.]{0,9}$/;
/** Decimal currencies settled to 2 minor units in this spec's scope. */
const MINOR_UNIT_EXPONENT = 2;

/**
 * Classifies a blotter security as an FX pair, an equity ticker, or
 * not settleable. Currency codes standing alone ('USD') are NOT instruments
 * — a single code is not a tradeable pair in this blotter's universe.
 */
export function parseSettlementInstrument(security) {
    const s = String(security ?? '').trim().toUpperCase();
    if (FX_PAIR.test(s)) {
        const [base, quote] = s.split('/');
        if (ISO4217_CURRENCIES.has(base) && ISO4217_CURRENCIES.has(quote)) {
            return { kind: 'fx', base, quote };
        }
        return { kind: 'invalid', reason: 'fx_leg_not_iso4217' };
    }
    if (ISO4217_CURRENCIES.has(s)) {
        return { kind: 'invalid', reason: 'bare_currency_not_settleable' };
    }
    if (EQUITY_TICKER.test(s)) {
        return { kind: 'equity', ticker: s };
    }
    return { kind: 'invalid', reason: 'security_not_settleable' };
}

/**
 * Rounds a cash amount to the currency's minor units with float-drift
 * correction — 14020.964999999998 must not survive to the wire.
 */
export function roundMinorUnit(amountRaw, exponent = MINOR_UNIT_EXPONENT) {
    const scale = 10 ** exponent;
    const corrected = Number(amountRaw) + Number.EPSILON * Math.round(Math.abs(amountRaw));
    return Math.round(corrected * scale) / scale;
}

/**
 * Builds the fdc3.payment payload fields for a trade, or a rejection.
 *
 * @param {object} trade — { security, quantity, price, side }
 * @param {object} desks — { executionDesk: {name, account}, counterpartyDesk: {name, account} }
 * @returns {ok:true, instruction} | {ok:false, reason}
 */
export function buildPaymentInstruction(trade, desks) {
    const instrument = parseSettlementInstrument(trade?.security);
    if (instrument.kind === 'invalid') {
        return { ok: false, reason: instrument.reason };
    }
    const quantity = Number(trade.quantity);
    const price = Number(trade.price);
    if (!Number.isFinite(quantity) || quantity <= 0) {
        return { ok: false, reason: 'quantity_invalid' };
    }
    if (!Number.isFinite(price) || price <= 0) {
        return { ok: false, reason: 'price_invalid' };
    }
    if (!desks?.executionDesk?.name || !desks?.executionDesk?.account
        || !desks?.counterpartyDesk?.name || !desks?.counterpartyDesk?.account) {
        return { ok: false, reason: 'parties_incomplete' };
    }
    // The buyer owes the cash leg on both instrument classes (equity purchase;
    // base-currency purchase on an FX pair) — debtor/creditor follow the side.
    const debtor = trade.side === 'Sell' ? desks.counterpartyDesk : desks.executionDesk;
    const creditor = trade.side === 'Sell' ? desks.executionDesk : desks.counterpartyDesk;
    const sideAdjust = { debtor, creditor };

    if (instrument.kind === 'fx') {
        return {
            ok: true,
            instruction: {
                currency: instrument.base,
                pair: `${instrument.base}/${instrument.quote}`,
                rate: price,
                amount: roundMinorUnit(quantity),
                ...sideAdjust
            }
        };
    }
    // Equity: same-currency cash transfer of the venue-currency notional.
    return {
        ok: true,
        instruction: {
            currency: VENUE_QUOTE_CURRENCY,
            pair: null,
            rate: null,
            amount: roundMinorUnit(quantity * price),
            ...sideAdjust
        }
    };
}

/**
 * Applies the mapping's optional-field contract to the wire: pair and rate
 * travel only when present, so an equity cash leg carries neither — and the
 * receiver-side validator's pair/rate coupling has nothing to break on.
 */
export function stripAbsentPaymentFields(instruction) {
    const { pair, rate, ...rest } = instruction;
    return pair == null ? rest : instruction;
}