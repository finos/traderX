"""Apply scoped HTTP order/quote snapshot refresh to an extracted Angular candidate."""
from pathlib import Path
from render_account_security import replace_once


def section(source, start, end, replacement):
    if source.count(start)!=1 or source.count(end)!=1:
        raise ValueError('Pinned order consumer boundary changed')
    a,b=source.index(start),source.index(end)
    if a>=b:raise ValueError('Invalid order consumer boundary')
    return source[:a]+replacement+'\n\n'+source[b:]


def orders(source):
    source="import { SnapshotPoll } from 'main/app/security/snapshot-poll';\n"+source
    source=replace_once(source,'  rows: OrderRow[] = [];','''  rows: OrderRow[] = [];
  actionError: string | null = null;
  private orderSnapshot?: SnapshotPoll<OrderRecord>;
  private quoteSnapshot?: SnapshotPoll<PriceTick>;''')
    source=replace_once(source,'''    this.orderAdminService.cancelOrder(orderId).subscribe();''','''    this.actionError = null;
    this.orderAdminService.cancelOrder(orderId).subscribe({
      next: () => this.orderSnapshot?.refresh(),
      error: () => {
        this.actionError = 'Cancellation was not accepted. Account permissions and current order state still apply.';
        this.orderSnapshot?.refresh();
      }
    });''')
    source=replace_once(source,'''  ngOnDestroy(): void {
    this.orderUnsubscribeFn?.();
    this.priceUnsubscribeFn?.();
  }''','''  ngOnDestroy(): void {
    this.orderUnsubscribeFn?.(); this.priceUnsubscribeFn?.();
    this.orderSnapshot?.dispose(); this.quoteSnapshot?.dispose();
    this.rows = []; this.setGridRowData([]);
  }''')
    return section(source,'  private startScope(): void {','  private applyOrderUpdate(','''  private startScope(): void {
    this.orderUnsubscribeFn?.(); this.priceUnsubscribeFn?.();
    this.orderSnapshot?.dispose(); this.quoteSnapshot?.dispose();
    this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear();
    this.rows = []; this.actionError = null; this.setGridRowData([]);
    const all = this.allAccountsMode;
    const account = this.account?.id;
    const ids = new Set((all ? Object.keys(this.accountNameById).map(Number) : [account])
      .filter((id): id is number => Number.isSafeInteger(id) && Number(id) > 0));
    if (!ids.size) return;
    this.quoteSnapshot = new SnapshotPoll<PriceTick>(
      () => this.priceSnapshots.getPrices(this.rows.map(row => row.security)),
      snapshots => {
        this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear();
        for (const quote of snapshots) if (quote?.ticker && quote.price != null)
          this.applyMarketPriceUpdate(quote.ticker, quote.price, quote.asOf ?? null);
        this.rows = this.rows.map(row => this.withLivePricing(row)); this.setGridRowData(this.rows);
      });
    this.orderSnapshot = new SnapshotPoll<OrderRecord>(
      () => this.orderAdminService.getOpenOrders(all ? undefined : account),
      orders => {
        this.rows = orders.filter(order => order && ids.has(order.accountId) && !this.isTerminalStatus(order.status))
          .map(order => this.withLivePricing(order));
        this.setGridRowData(this.rows); this.quoteSnapshot?.refresh();
      });
    const subscriptions = [...ids].map(id => this.tradeFeed.subscribeSettlement(
      `/accounts/${id}/trades`, () => this.orderSnapshot?.refresh()));
    const connection = this.tradeFeed.connectionState$.subscribe(state => {
      if (state === 'connected') { this.orderSnapshot?.refresh(); this.quoteSnapshot?.refresh(); }
    });
    this.orderUnsubscribeFn = () => { subscriptions.forEach(remove => remove()); connection.unsubscribe(); };
  }

  private reloadOpenOrders(): void { this.orderSnapshot?.refresh(); }''')


def ticket(source):
    source="import { SnapshotPoll } from 'main/app/security/snapshot-poll';\nimport { map } from 'rxjs';\n"+source
    source=replace_once(source,'  private priceStreamUnsubscribeFn?: Function;','  private priceStreamUnsubscribeFn?: Function;\n  private quoteSnapshot?: SnapshotPoll<PriceTick>;')
    source=source.replace("return 'Streaming...';","return 'Price unavailable';")
    start='''    this.priceSnapshots.getPrice(normalizedTicker).subscribe((snapshot) => {'''
    end='  private applyPriceCandidate('
    replacement='''    const snapshot = new SnapshotPoll<PriceTick>(
      () => this.priceSnapshots.getPrice(normalizedTicker).pipe(map(value => value ? [value] : [])),
      quotes => {
        if (this.selectedPriceTicker !== normalizedTicker) return;
        if (!quotes.length) { this.selectedPrice = null; this.selectedPriceAsOf = null; return; }
        const quote = quotes[0];
        this.applyPriceCandidate(normalizedTicker, quote.price, quote.asOf ?? null, true);
      });
    this.quoteSnapshot = snapshot;
    this.priceStreamUnsubscribeFn = () => snapshot.dispose();
  }
'''
    return section(source,start,end,replacement)


def apply(target):
    app=Path(target)/'main/app'
    path=app/'trade/order-blotter/order-blotter.component.ts'
    path.write_text(orders(path.read_text()))
    html=app/'trade/order-blotter/order-blotter.component.html'
    html.write_text('<p *ngIf="actionError" role="alert">{{ actionError }}</p>\n'+html.read_text())
    path=app/'trade/order-ticket/order-ticket.component.ts'
    path.write_text(ticket(path.read_text()))
