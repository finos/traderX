import { Injectable } from '@angular/core';

export interface Fdc3InstrumentContext {
    type: 'fdc3.instrument';
    id: {
        ticker: string;
        [key: string]: string;
    };
}

type InstrumentContextLike = {
    type?: unknown;
    id?: { [key: string]: unknown } | null;
} | null | undefined;

@Injectable({
    providedIn: 'root'
})
export class Fdc3TickerCompatibilityBridgeService {
    normalizeTicker(rawTicker: string | null | undefined): string | undefined {
        if (typeof rawTicker !== 'string') {
            return undefined;
        }
        let normalized = rawTicker.trim().toUpperCase();
        if (!normalized) {
            return undefined;
        }
        if (normalized.includes(':')) {
            normalized = normalized.split(':').pop() ?? normalized;
        }
        normalized = normalized.replace(/\s+/g, '');
        return normalized || undefined;
    }

    toInteropTicker(rawTraderxTicker: string | null | undefined): string | undefined {
        return this.normalizeTicker(rawTraderxTicker);
    }

    fromInteropTicker(rawInteropTicker: string | null | undefined): string | undefined {
        return this.normalizeTicker(rawInteropTicker);
    }

    toInstrumentContext(rawTraderxTicker: string | null | undefined): Fdc3InstrumentContext | undefined {
        const interopTicker = this.toInteropTicker(rawTraderxTicker);
        if (!interopTicker) {
            return undefined;
        }
        return {
            type: 'fdc3.instrument',
            id: {
                ticker: interopTicker
            }
        };
    }

    toViewInstrumentIntentContext(rawTraderxTicker: string | null | undefined): Fdc3InstrumentContext | undefined {
        return this.toInstrumentContext(rawTraderxTicker);
    }

    fromInstrumentContext(context: InstrumentContextLike): string | undefined {
        if (!context || typeof context !== 'object') {
            return undefined;
        }
        if (typeof context.type === 'string' && context.type !== 'fdc3.instrument') {
            return undefined;
        }
        const ticker = context.id && typeof context.id.ticker === 'string' ? context.id.ticker : undefined;
        return this.fromInteropTicker(ticker);
    }
}
