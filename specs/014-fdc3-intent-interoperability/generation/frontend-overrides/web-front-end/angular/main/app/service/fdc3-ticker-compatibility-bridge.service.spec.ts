import { Fdc3TickerCompatibilityBridgeService } from './fdc3-ticker-compatibility-bridge.service';

describe('Fdc3TickerCompatibilityBridgeService', () => {
    let service: Fdc3TickerCompatibilityBridgeService;

    beforeEach(() => {
        service = new Fdc3TickerCompatibilityBridgeService();
    });

    it('should normalize outbound TraderX tickers without remapping symbols', () => {
        expect(service.toInteropTicker(' ibm ')).toEqual('IBM');
        expect(service.toInteropTicker('MS')).toEqual('MS');
        expect(service.toInteropTicker('nvda')).toEqual('NVDA');
    });

    it('should normalize inbound interop tickers without remapping symbols', () => {
        expect(service.fromInteropTicker('aapl')).toEqual('AAPL');
        expect(service.fromInteropTicker('NASDAQ:msft')).toEqual('MSFT');
        expect(service.fromInteropTicker('ORCL')).toEqual('ORCL');
    });

    it('should produce fdc3.instrument context from a TraderX ticker', () => {
        expect(service.toInstrumentContext('c')).toEqual({
            type: 'fdc3.instrument',
            id: {
                ticker: 'C'
            }
        });
    });

    it('should keep TradingView ticker payloads as bare canonical symbols', () => {
        expect(service.toTradingViewTicker('c')).toEqual('C');
        expect(service.toTradingViewTicker('msft')).toEqual('MSFT');
        expect(service.toTradingViewTicker('ORCL')).toEqual('ORCL');
    });

    it('should use bare ticker for ViewInstrument intent context', () => {
        expect(service.toViewInstrumentIntentContext('c')).toEqual({
            type: 'fdc3.instrument',
            id: {
                ticker: 'C'
            }
        });
    });

    it('should extract a TraderX ticker from inbound instrument context', () => {
        expect(service.fromInstrumentContext({
            type: 'fdc3.instrument',
            id: {
                ticker: 'NASDAQ:AMZN'
            }
        })).toEqual('AMZN');
    });

    it('should return undefined for malformed context payloads', () => {
        expect(service.fromInstrumentContext(undefined)).toBeUndefined();
        expect(service.fromInstrumentContext(null)).toBeUndefined();
        expect(service.fromInstrumentContext({ type: 'fdc3.contact', id: { ticker: 'AAPL' } })).toBeUndefined();
        expect(service.fromInstrumentContext({ type: 'fdc3.instrument', id: {} })).toBeUndefined();
    });
});
