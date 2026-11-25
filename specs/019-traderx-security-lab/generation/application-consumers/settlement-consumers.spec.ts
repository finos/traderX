import { fakeAsync, tick } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';
import { SettlementSnapshot, settlementMatches } from './settlement-snapshot';
import { TradeBlotterComponent } from '../trade/trade-blotter/trade-blotter.component';
import { PositionBlotterComponent } from '../trade/position-blotter/position-blotter.component';
import { TradeFeedService } from '../service/trade-feed.service';

function envelope(accountId = 22214) {
    const executionId = '00000000-0000-4000-8000-000000000001';
    return { executionId, eventId: executionId + ':trade', eventKind: 'trade.settled',
        eventSequence: 1, payload: { accountId, price: 999999, quantity: 999999 } };
}
function feed() {
    const callbacks = new Map<string, () => void>();
    const state = new Subject<string>();
    return { callbacks, state, connectionState$: state.asObservable(),
        subscribe: () => () => {},
        subscribeSettlement: (topic: string, callback: () => void) => {
            callbacks.set(topic, callback); return () => callbacks.delete(topic);
        } };
}

describe('Settlement notification contract', () => {
    it('rejects foreign, malformed and legacy envelopes', () => {
        const topic = '/accounts/22214/trades';
        expect(settlementMatches(topic, envelope())).toBeTrue();
        for (const value of [envelope(62654), { payload: {} }, {...envelope(), eventSequence: 0},
            {...envelope(), eventId: 'wrong'}, {...envelope(), extra: true}, {...envelope(), payload: null}]) {
            expect(!!settlementMatches(topic, value)).toBeFalse();
        }
        expect(settlementMatches('/accounts/*/trades', envelope())).toBeFalse();
    });
    it('checks actual broker subject before emitting an invalidation without payload', () => {
        const service: any = Object.create(TradeFeedService.prototype);
        const callback = jasmine.createSpy('invalidate');
        service.subscriptions = new Map([[1, {topic:'/accounts/22214/trades', settlement:true, callback}]]);
        service.dispatchMessage(1, JSON.stringify(envelope()), '/accounts/62654/trades');
        expect(callback).not.toHaveBeenCalled();
        service.dispatchMessage(1, JSON.stringify(envelope()), '/accounts/22214/trades');
        expect(callback).toHaveBeenCalledOnceWith();
    });
});

describe('Bounded snapshot refresher', () => {
    it('coalesces bursts and refreshes once after an in-flight invalidation', fakeAsync(() => {
        const first = new Subject<number[]>();
        const fetch = jasmine.createSpy().and.returnValues(first, of([2]));
        const apply = jasmine.createSpy();
        const snapshot = new SettlementSnapshot(fetch, apply);
        for (let i=0;i<100;i++) snapshot.refresh();
        tick(100); expect(fetch).toHaveBeenCalledTimes(1);
        for (let i=0;i<100;i++) snapshot.refresh();
        tick(300); expect(fetch).toHaveBeenCalledTimes(1);
        first.next([1]); tick(100);
        expect(fetch).toHaveBeenCalledTimes(2);
        expect(apply.calls.allArgs()).toEqual([[[1]], [[2]]]);
        snapshot.dispose();
    }));
    it('cancels obsolete scope requests and queued timers', fakeAsync(() => {
        const response = new Subject<number[]>(); const apply = jasmine.createSpy();
        const fetch = jasmine.createSpy().and.returnValue(response);
        const snapshot = new SettlementSnapshot(fetch, apply);
        snapshot.refresh(); tick(100); snapshot.refresh(); snapshot.dispose();
        response.next([999]); tick(1000);
        expect(apply).not.toHaveBeenCalled(); expect(fetch).toHaveBeenCalledTimes(1);
    }));
    it('clears stale data on denied HTTP and bounds a stalled request', fakeAsync(() => {
        const apply = jasmine.createSpy();
        const fetch = jasmine.createSpy().and.returnValues(throwError(() => new Error('denied')), new Subject());
        const snapshot = new SettlementSnapshot(fetch, apply);
        snapshot.refresh(); tick(100); expect(apply).toHaveBeenCalledWith([]);
        snapshot.refresh(); tick(5100); expect(apply).toHaveBeenCalledTimes(2);
        snapshot.dispose();
    }));
});

describe('Actual application blotter consumers', () => {
    it('refreshes trades from HTTP, never from notification values, and handles reconnect', fakeAsync(() => {
        const bus = feed();
        const api = {getTrades: jasmine.createSpy().and.returnValue(of([{id:'one', accountId:22214, price:10}]))};
        const component = new TradeBlotterComponent(bus as any, api as any);
        component.account = {id:22214} as any;
        component.ngOnChanges({account: {} as any}); tick(100);
        expect(component.trades[0].price).toBe(10);
        api.getTrades.and.returnValue(of([{id:'one', accountId:22214, price:11}]));
        (bus.callbacks.get('/accounts/22214/trades') as any)(envelope()); tick(100);
        expect(component.trades[0].price).toBe(11);
        bus.state.next('connected'); tick(100); expect(api.getTrades).toHaveBeenCalledTimes(3);
        component.ngOnDestroy();
    }));
    it('drops an old-account HTTP response after scope change', fakeAsync(() => {
        const bus = feed(); const old = new Subject<any[]>();
        const api = {getTrades: jasmine.createSpy().and.returnValues(old, of([{id:'new', accountId:62654}]))};
        const component = new TradeBlotterComponent(bus as any, api as any);
        const grid = {setGridOption: jasmine.createSpy()};
        component.gridApi = grid as any;
        component.account = {id:22214} as any; component.ngOnChanges({account:{} as any}); tick(100);
        component.account = {id:62654} as any; component.ngOnChanges({account:{} as any});
        expect(component.trades).toEqual([]);
        expect(grid.setGridOption).toHaveBeenCalledWith('rowData', []);
        tick(100);
        old.next([{id:'private-old', accountId:22214}]);
        expect(component.trades.map(t => t.id)).toEqual(['new']);
        expect(bus.callbacks.has('/accounts/22214/trades')).toBeFalse();
        component.ngOnDestroy();
    }));
    it('filters HTTP position results to the selected account and clears on denial', fakeAsync(() => {
        const bus = feed();
        const api = {getPositions: jasmine.createSpy().and.returnValue(of([
            {accountId:22214, security:'IBM', quantity:1, averageCostBasis:10},
            {accountId:62654, security:'PRIVATE', quantity:999, averageCostBasis:1}]))};
        const component = new PositionBlotterComponent(api as any, bus as any, {getPrices:() => of([])} as any);
        component.account = {id:22214} as any; component.ngOnChanges({account:{} as any}); tick(100);
        expect(component.positions.map((p:any) => p.security)).toEqual(['IBM']);
        api.getPositions.and.returnValue(throwError(() => new Error('denied')));
        bus.callbacks.get('/accounts/22214/positions')!(); tick(100);
        expect(component.positions).toEqual([]);
        component.ngOnDestroy();
    }));
});
