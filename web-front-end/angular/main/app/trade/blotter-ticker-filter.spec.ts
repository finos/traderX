import { TestBed } from '@angular/core/testing';
import { CommonModule } from '@angular/common';
import { AgGridModule } from 'ag-grid-angular';
import { BehaviorSubject, Subject, of } from 'rxjs';
import { TradeComponent } from './trade.component';
import { OrderBlotterComponent } from './order-blotter/order-blotter.component';
import { TradeBlotterComponent } from './trade-blotter/trade-blotter.component';
import { PositionBlotterComponent } from './position-blotter/position-blotter.component';
import { Fdc3InteropService } from '../service/fdc3-interop.service';
import { Fdc3TickerCompatibilityBridgeService } from '../service/fdc3-ticker-compatibility-bridge.service';
import { TradeFeedService } from '../service/trade-feed.service';
import { OrderAdminService } from '../service/order-admin.service';
import { PositionService } from '../service/position.service';
import { PriceSnapshotService } from '../service/price-snapshot.service';

// Real generated components, templates, AG Grid and TraderX FDC3 adapter.
// Only the DesktopAgent boundary and backend data transport are controlled.
describe('FDC3 blotter filtering', () => {
  let interop: Fdc3InteropService;
  let listeners: Map<string, Function>;
  let connection: BehaviorSubject<string>;
  let callbacks: Map<string, Function>;
  let snapshots: Subject<any[]>[];
  let feed: any;
  let orders: any;
  let positions: any;
  const prices = { getPrices: () => of([]) };
  const row = (security: string, id = security, status = 'NEW') => ({
    security, id, orderId: id, accountId: 1, accountid: 1, status,
    quantity: 5, remainingQuantity: 5, limitPrice: 10, averageCostBasis: 10,
    side: 'Buy', updatedAt: '2026-09-17T10:00:00Z'
  });

  beforeEach(async () => {
    listeners = new Map(); callbacks = new Map(); snapshots = [];
    connection = new BehaviorSubject('disconnected');
    feed = { connectionState$: connection, subscribe: (topic: string, callback: Function) => {
      callbacks.set(topic, callback); return () => callbacks.delete(topic);
    }};
    const snapshot = () => { const subject = new Subject<any[]>(); snapshots.push(subject); return subject; };
    orders = { getOpenOrders: snapshot, subscribe: feed.subscribe };
    positions = { getPositions: snapshot, getAllPositions: snapshot, getTrades: snapshot, getAllTrades: snapshot };
    interop = new Fdc3InteropService(new Fdc3TickerCompatibilityBridgeService());
    await (interop as any).registerListeners({
      addContextListener: (type: string, handler: Function) => { listeners.set(type, handler); },
      addIntentListener: (intent: string, handler: Function) => { listeners.set(intent, handler); }
    });
    await TestBed.configureTestingModule({
      declarations: [OrderBlotterComponent, TradeBlotterComponent, PositionBlotterComponent],
      imports: [CommonModule, AgGridModule],
      providers: [
        { provide: Fdc3InteropService, useValue: interop },
        { provide: TradeFeedService, useValue: feed },
        { provide: OrderAdminService, useValue: orders },
        { provide: PositionService, useValue: positions },
        { provide: PriceSnapshotService, useValue: prices }
      ]
    }).compileComponents();
  });

  function select(ticker: unknown) { listeners.get('fdc3.instrument')!({ type: 'fdc3.instrument', id: { ticker } }); }
  function scope(component: any, id: number) {
    component.account = { id, displayName: `Account ${id}` };
    component.ngOnChanges({ account: {} });
  }

  for (const kind of ['orders', 'trades', 'positions']) {
    it(`${kind}: independent opt-in uses latest exact ticker and resets in a new instance`, () => {
      const make = (): any => kind === 'orders' ? new OrderBlotterComponent(orders, feed, prices as any, interop)
        : kind === 'trades' ? new TradeBlotterComponent(feed, positions, interop)
        : new PositionBlotterComponent(positions, feed, prices as any, interop);
      select('MS');
      const a = make(), b = make();
      expect(a.isExternalFilterPresent()).toBeFalse();
      a.setTickerFilter(true);
      expect(a.doesExternalFilterPass({ data: row('MS') })).toBeTrue();
      expect(a.doesExternalFilterPass({ data: row('MSFT') })).toBeFalse();
      expect(b.isExternalFilterPresent()).toBeFalse();
      select('AAPL');
      expect(a.effectiveTicker).toBe('AAPL');
      a.setTickerFilter(false);
      select('IBM');
      expect(interop.selectedTicker$.value).toBe('IBM');
      a.setTickerFilter(true);
      expect(a.effectiveTicker).toBe('IBM');
      scope(a, 2);
      expect(a.effectiveTicker).toBe('IBM');
      const popout = make();
      expect(popout.isExternalFilterPresent()).toBeFalse();
      expect(popout.securityFilter).toBe('IBM');
      a.ngOnDestroy(); b.ngOnDestroy(); popout.ngOnDestroy();
    });
  }

  it('ignores missing, empty and invalid contexts without corrupting selection', () => {
    const component = new OrderBlotterComponent(orders, feed, prices as any, interop);
    component.setTickerFilter(true);
    expect(component.tickerFilterDescription).toContain('no ticker selected');
    select('NASDAQ:msft');
    for (const value of [null, undefined, '', {}, 42]) select(value);
    listeners.get('fdc3.instrument')!({ id: { ticker: 'WRONG' } });
    expect(component.effectiveTicker).toBe('MSFT');
    component.ngOnDestroy();
  });


  it('recovers retained channel selection without changing a local mode or replaying invalid data', async () => {
    const component = new OrderBlotterComponent(orders, feed, prices as any, interop);
    const contexts: any = {
      'fdc3.instrument': { type: 'fdc3.instrument', id: { ticker: 'IBM' } },
      'fdc3.account': { type: 'fdc3.account', id: { accountId: '1' } }
    };
    const agent = { getUserChannels: () => [], joinUserChannel: () => undefined, getCurrentChannel: () => ({ id: 'One', getCurrentContext: (type: string) => contexts[type] }) };
    await (interop as any).syncContextFromActiveChannel(agent);
    expect(component.securityFilter).toBe('IBM');
    expect(component.filterOnSelectedTicker).toBeFalse();
    const broadcasts = jasmine.createSpy('broadcast');
    (interop as any).agent = { ...agent, broadcast: broadcasts };
    component.setTickerFilter(true);
    component.setTickerFilter(false);
    expect(broadcasts).not.toHaveBeenCalled();
    expect(interop.selectedTicker$.value).toBe('IBM');
    contexts['fdc3.instrument'] = null;
    await (interop as any).syncContextFromActiveChannel(agent);
    expect(interop.selectedTicker$.value).toBe('IBM');
    component.ngOnDestroy();
  });

  it('rebroadcasts a previous local ticker after another app changed the selection', async () => {
    const broadcast = jasmine.createSpy('broadcast').and.resolveTo();
    (interop as any).agent = { broadcast, getCurrentChannel: () => ({ id: 'One', broadcast }) };
    await interop.publishTickerSelection('IBM');
    select('MSFT');
    await interop.publishTickerSelection('IBM');
    expect(broadcast).toHaveBeenCalledTimes(2);
    expect(interop.selectedTicker$.value).toBe('IBM');
  });

  it('keeps ticket intent selection and account propagation independent of blotter mode', () => {
    const show = jasmine.createSpy('show');
    const page = new TradeComponent(
      { getAccounts: () => of([{ id: 1, displayName: 'One' }, { id: 2, displayName: 'Two' }]) } as any,
      { getStocks: () => of([]) } as any, orders,
      { getAllPositions: () => of([]) } as any, feed, { show } as any, interop
    );
    page.tradeTicketTemplate = {} as any;
    page.orderTicketTemplate = {} as any;
    page.ngOnInit();
    const blotter = new OrderBlotterComponent(orders, feed, prices as any, interop);
    listeners.get('TraderX.CreateTradeTicket')!({ type: 'fdc3.instrument', id: { ticker: 'IBM' } });
    expect(page.tradeTicketPresetSecurity).toBe('IBM');
    expect(show).toHaveBeenCalled();
    expect(blotter.filterOnSelectedTicker).toBeFalse();
    listeners.get('ViewOrders')!({ type: 'fdc3.instrument', id: { ticker: 'MSFT' } });
    expect(page.activeBlotter).toBe('orders');
    expect(blotter.filterOnSelectedTicker).toBeFalse();
    blotter.setTickerFilter(true);
    listeners.get('fdc3.account')!({ type: 'fdc3.account', id: { accountId: '2' } });
    expect(page.accountModel!.id).toBe(2);
    expect(blotter.effectiveTicker).toBe('MSFT');
    listeners.get('TraderX.CreateOrderTicket')!({ type: 'fdc3.instrument', id: { ticker: 'AAPL' } });
    expect(page.orderTicketPresetSecurity).toBe('AAPL');
    blotter.setTickerFilter(false);
    expect(page.orderTicketPresetSecurity).toBe('AAPL');
    blotter.ngOnDestroy(); page.ngOnDestroy();
  });

  it('receives valid account context independently of instrument context', () => {
    select('IBM');
    listeners.get('fdc3.account')!({ type: 'fdc3.account', id: { accountId: '2' } });
    listeners.get('fdc3.account')!({ type: 'fdc3.account', id: { accountId: '-1' } });
    expect(interop.selectedAccountId$.value).toBe(2);
    expect(interop.selectedTicker$.value).toBe('IBM');
  });

  it('keeps creates and cancellation tombstones over a delayed snapshot; cancels obsolete scope and reconnects', () => {
    const component = new OrderBlotterComponent(orders, feed, prices as any, interop);
    scope(component, 1);
    const first = snapshots[0];
    callbacks.get('/accounts/1/orders')!(row('IBM', 'cancelled', 'CANCELED'));
    callbacks.get('/accounts/1/orders')!(row('AAPL', 'created'));
    first.next([row('IBM', 'cancelled')]);
    expect(component.rows.map(item => item.orderId)).toEqual(['created']);
    select('AAPL'); component.setTickerFilter(true);
    scope(component, 2);
    expect(first.observed).toBeFalse();
    first.next([row('IBM', 'stale')]);
    expect(component.rows).toEqual([]);
    connection.next('connected');
    expect(snapshots[1].observed).toBeFalse();
    snapshots[2].next([{ ...row('AAPL', 'reconnected'), accountId: 2 }]);
    expect(component.rows[0].orderId).toBe('reconnected');
    expect(component.effectiveTicker).toBe('AAPL');
    component.ngOnDestroy();
  });

  for (const kind of ['trades', 'positions']) {
    it(`${kind}: replays events into authoritative rows before Angular renders and cancels old account requests`, () => {
      const component: any = kind === 'trades' ? new TradeBlotterComponent(feed, positions, interop)
        : new PositionBlotterComponent(positions, feed, prices as any, interop);
      scope(component, 1);
      callbacks.get(`/accounts/1/${kind}`)!({ ...row('IBM'), quantity: 9 });
      snapshots[0].next([row('IBM')]);
      expect(component[kind][0].quantity).toBe(9);
      scope(component, 2);
      expect(snapshots[0].observed).toBeFalse();
      snapshots[0].next([row('WRONG')]);
      expect(component[kind]).toEqual([]);
      component.ngOnDestroy();
    });
  }

  for (const type of [OrderBlotterComponent, TradeBlotterComponent, PositionBlotterComponent]) {
    it(`${type.name}: renders a labelled native control and filters actual AG Grid rows`, async () => {
      const fixture = TestBed.createComponent(type as typeof OrderBlotterComponent);
      fixture.componentRef.setInput('account', { id: 1, displayName: 'Test' });
      fixture.detectChanges();
      snapshots[0].next([row('MS'), row('MSFT')]);
      await fixture.whenStable();
      fixture.detectChanges();
      await new Promise(resolve => setTimeout(resolve, 50));
      const component = fixture.componentInstance;
      select('MS');
      expect(component.gridApi!.getDisplayedRowCount()).toBe(2);
      const control: HTMLSelectElement = fixture.nativeElement.querySelector('label select');
      expect(control.options[0].text).toBe('All tickers');
      control.value = 'selected'; control.dispatchEvent(new Event('change'));
      fixture.detectChanges();
      expect(component.gridApi!.getDisplayedRowCount()).toBe(1);
      expect(fixture.nativeElement.querySelector('[role=status]').textContent).toContain('MS');
      control.value = 'all'; control.dispatchEvent(new Event('change'));
      expect(component.gridApi!.getDisplayedRowCount()).toBe(2);
      fixture.destroy();
    });
  }
});
