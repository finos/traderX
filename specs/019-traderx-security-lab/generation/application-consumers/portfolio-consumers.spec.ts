import { fakeAsync, tick } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';
import { PositionBlotterComponent } from '../trade/position-blotter/position-blotter.component';
import { TradeComponent } from '../trade/trade.component';

function bus() {
    const state = new Subject<string>(); const callbacks = new Map<string, () => void>();
    return { state, callbacks, connectionState$: state.asObservable(),
        subscribe: () => { throw new Error('Legacy broker transport must not be used'); },
        subscribeSettlement: (topic: string, cb: () => void) => { callbacks.set(topic, cb); return () => callbacks.delete(topic); } };
}
function position(accountId: number, quantity = 2) { return { accountId, security: 'IBM', quantity, averageCostBasis: 10 }; }
function quote(price = 20, age = 0) { return { ticker: 'IBM', price, openPrice: 19, asOf: new Date(Date.now() - age).toISOString() }; }
function scope(component: PositionBlotterComponent, id: number) {
    component.account = { id } as any; component.ngOnChanges({ account: {} as any });
}

describe('Actual scoped portfolio snapshot consumers', () => {
    it('refreshes valuations and quantities from HTTP after polling, settlement and reconnect', fakeAsync(() => {
        const feed = bus(); const api = { getPositions: jasmine.createSpy().and.returnValue(of([position(22214), position(62654, 100)])) };
        const prices = { getPrices: jasmine.createSpy().and.callFake(() => of([quote()])) };
        const component = new PositionBlotterComponent(api as any, feed as any, prices as any);
        const totals: any[] = []; component.summaryChange.subscribe(value => totals.push(value));
        scope(component, 22214); tick(300);
        expect(component.positions.length).toBe(1); expect(component.positions[0].marketValue).toBe(40);
        expect(totals[totals.length - 1].totalPnl).toBe(20);
        prices.getPrices.and.callFake(() => of([quote(25)])); tick(2100);
        expect(component.positions[0].marketValue).toBe(50);
        api.getPositions.and.returnValue(of([position(22214, 3)]));
        feed.callbacks.get('/accounts/22214/positions')!(); tick(300);
        expect(component.positions[0].marketValue).toBe(75);
        const before = api.getPositions.calls.count(); feed.state.next('connected'); tick(300);
        expect(api.getPositions.calls.count()).toBeGreaterThan(before);
        component.ngOnDestroy(); const calls = api.getPositions.calls.count(); tick(10000);
        expect(api.getPositions.calls.count()).toBe(calls); expect(feed.callbacks.size).toBe(0);
    }, { flush: false }));

    it('aggregates only authorized accounts and uses current quotes for All Accounts', fakeAsync(() => {
        const component = new PositionBlotterComponent({ getAllPositions: () => of([
            position(22214), position(62654, 3), position(99999, 100)
        ]) } as any, bus() as any, { getPrices: () => of([quote(30)]) } as any);
        component.allAccountsMode = true; component.accountIds = [22214, 62654];
        component.ngOnChanges({ allAccountsMode: {} as any }); tick(300);
        expect(component.positions.length).toBe(1);
        expect(component.positions[0].quantity).toBe(5); expect(component.positions[0].marketValue).toBe(150);
        component.ngOnDestroy();
    }, { flush: false }));

    it('clears missing, expired and invalid quotes instead of substituting cost basis or zero', fakeAsync(() => {
        const prices = { getPrices: jasmine.createSpy().and.callFake(() => of([quote()])) };
        const component = new PositionBlotterComponent({ getPositions: () => of([position(22214)]) } as any, bus() as any, prices as any);
        const totals: any[] = []; component.summaryChange.subscribe(value => totals.push(value));
        scope(component, 22214); tick(300); expect(component.positions[0].marketValue).toBe(40);
        for (const candidates of [[], [quote(30, 61000)], [quote(0)], [quote(20, -60000)]]) {
            prices.getPrices.and.returnValue(of(candidates)); tick(2100);
            expect(component.positions[0].marketPrice).toBeNull(); expect(component.positions[0].pnl).toBeNull();
            expect(Number.isNaN(totals[totals.length - 1].totalMarketValue)).toBeTrue();
            expect(totals[totals.length - 1].totalCostBasis).toBe(20);
        }
        component.ngOnDestroy();
    }, { flush: false }));

    it('cancels old-account position and quote responses and clears denied snapshots', fakeAsync(() => {
        const oldPosition = new Subject<any[]>(); const oldQuote = new Subject<any[]>(); const feed = bus();
        const api = { getPositions: jasmine.createSpy().and.returnValues(oldPosition, of([position(62654)])) };
        let quoteRequests = 0;
        const prices = { getPrices: jasmine.createSpy().and.callFake(() => ++quoteRequests === 1 ? oldQuote : of([quote(21)])) };
        const component = new PositionBlotterComponent(api as any, feed as any, prices as any);
        const totals: any[] = []; component.summaryChange.subscribe(value => totals.push(value));
        scope(component, 22214); tick(100); scope(component, 62654);
        expect(component.positions).toEqual([]); expect(oldPosition.observed).toBeFalse(); expect(oldQuote.observed).toBeFalse();
        tick(300); oldPosition.next([position(22214, 999)]); oldQuote.next([quote(999)]);
        expect(component.positions[0].accountId).toBe(62654); expect(component.positions[0].marketPrice).toBe(21);
        api.getPositions.and.returnValue(throwError(() => new Error('denied')));
        feed.callbacks.get('/accounts/62654/positions')!(); tick(300);
        expect(component.positions).toEqual([]); expect(Number.isNaN(totals[totals.length - 1].totalCostBasis)).toBeTrue();
        component.ngOnDestroy();
    }, { flush: false }));

    it('distinguishes an authorized empty portfolio from a timed-out snapshot', fakeAsync(() => {
        const pending = new Subject<any[]>();
        const api = { getPositions: jasmine.createSpy().and.returnValue(of([])) };
        const feed = bus(); const component = new PositionBlotterComponent(api as any, feed as any, { getPrices: () => of([]) } as any);
        const totals: any[] = []; component.summaryChange.subscribe(value => totals.push(value));
        scope(component, 22214); tick(300);
        expect(totals[totals.length - 1].totalMarketValue).toBe(0);
        api.getPositions.and.returnValue(pending); feed.callbacks.get('/accounts/22214/positions')!(); tick(5200);
        expect(Number.isNaN(totals[totals.length - 1].totalMarketValue)).toBeTrue();
        component.ngOnDestroy(); expect(pending.observed).toBeFalse(); tick(10000);
    }, { flush: false }));

    it('uses the returned scoped summary without a second global position cache', () => {
        const api = { getAllPositions: jasmine.createSpy() }; const pendingAccounts = new Subject<any[]>();
        const parent = new TradeComponent({ getAccounts: () => pendingAccounts } as any,
            { getStocks: () => of([]) } as any, {} as any, api as any, bus() as any, {} as any);
        parent.ngOnInit(); parent.accountModel = { id: 0 } as any;
        const summary = { totalMarketValue: 150, totalCostBasis: 50, totalPnl: 100 };
        parent.onSummaryChange(summary);
        expect(parent.accountSummary).toBe(summary); expect(parent.portfolioSummary).toBe(summary);
        expect(api.getAllPositions).not.toHaveBeenCalled();
        parent.ngOnDestroy(); expect(pendingAccounts.observed).toBeFalse();
        expect(Number.isNaN(parent.accountSummary.totalMarketValue)).toBeTrue();
    });
});
