// Trade → payment-instruction mapping (Spec 016 cash-leg) — typed mirror of
// generation/payment-instruction.mjs. The mjs is the SSOT and carries the full
// rationale; keep the two in sync — the smoke tests
// (tests/smoke/payment-instruction.test.mjs) govern the mapping.
//
// The defect this fixes: the blotter sent `currency: trade.security`, so an
// equity order (BAC) produced `currency: 'BAC'`, `pair: 'BAC/KES'` and a
// floating-point notional (14020.964999999998). A payment instruction carries
// the trade's CASH obligation: an FX pair trade settles its base leg (rate =
// the fill); an equity trade is a same-currency transfer of the venue-currency
// notional (KES) with NO pair/rate — the blotter holds no FX data and none is
// invented. Parties follow the trade side: the buyer owes the cash.

export const VENUE_QUOTE_CURRENCY = 'KES';

export interface SettlementDesks {
    executionDesk: { name: string; account: string };
    counterpartyDesk: { name: string; account: string };
}

export interface PaymentInstruction {
    currency: string;
    pair: string | null;
    rate: number | null;
    amount: number;
    debtor: { name: string; account: string };
    creditor: { name: string; account: string };
}

export type SettlementInstrument =
    | { kind: 'fx'; base: string; quote: string }
    | { kind: 'equity'; ticker: string }
    | { kind: 'invalid'; reason: string };

/**
 * ISO 4217 active currency codes the desk admits — mirror of ISO4217_CURRENCIES
 * in generation/payment-instruction.mjs. Codes outside the set are not
 * currencies, however alpha-3-shaped they look ('BAC' is an equity symbol).
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

export function parseSettlementInstrument(security: unknown): SettlementInstrument {
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

/** Rounds to the currency's minor units with float-drift correction. */
export function roundMinorUnit(amountRaw: number, exponent = 2): number {
    const scale = 10 ** exponent;
    const corrected = Number(amountRaw) + Number.EPSILON * Math.round(Math.abs(amountRaw));
    return Math.round(corrected * scale) / scale;
}

interface InstructionTrade { security: unknown; quantity: unknown; price: unknown; side?: string | null }

export function buildPaymentInstruction(
    trade: InstructionTrade,
    desks: SettlementDesks
): { ok: true; instruction: PaymentInstruction } | { ok: false; reason: string } {
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
    const debtor = trade.side === 'Sell' ? desks.counterpartyDesk : desks.executionDesk;
    const creditor = trade.side === 'Sell' ? desks.executionDesk : desks.counterpartyDesk;

    if (instrument.kind === 'fx') {
        return {
            ok: true,
            instruction: {
                currency: instrument.base,
                pair: `${instrument.base}/${instrument.quote}`,
                rate: price,
                amount: roundMinorUnit(quantity),
                debtor, creditor
            }
        };
    }
    return {
        ok: true,
        instruction: {
            currency: VENUE_QUOTE_CURRENCY,
            pair: null,
            rate: null,
            amount: roundMinorUnit(quantity * price),
            debtor, creditor
        }
    };
}