"""Use one scoped position summary and cancellable HTTP quote snapshots."""
from pathlib import Path
from render_account_security import replace_once
from render_order_consumers import section


def positions(source):
    source = source.replace("import { SettlementSnapshot } from 'main/app/security/settlement-snapshot';", "import { SnapshotPoll } from 'main/app/security/snapshot-poll';\nimport { tap } from 'rxjs';")
    source = replace_once(source, '  private settlementSnapshot?: SettlementSnapshot<Position>;', '''  private settlementSnapshot?: SnapshotPoll<Position>;
  private quoteSnapshot?: SnapshotPoll<PriceTick>;
  private positionSource: Position[] = [];
  snapshotAvailable = false;''')
    source = section(source, '  private loadScope() {', '  private applyMarketPriceUpdate(', '''  private loadScope() {
    this.clearSubscriptions();
    this.positions = []; this.positionSource = []; this.pendingPosition = [];
    this.snapshotAvailable = false;
    this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear(); this.openPriceByTicker.clear();
    this.setGridRowData([]); this.emitSummary(); this.isPending = true;
    const all = this.allAccountsMode;
    const ids = new Set((all ? this.accountIds : [this.account?.id])
      .filter((id): id is number => Number.isSafeInteger(id) && Number(id) > 0));
    if (!ids.size) { this.isPending = false; return; }
    const account = [...ids][0];
    this.quoteSnapshot = new SnapshotPoll<PriceTick>(
      () => this.priceSnapshots.getPrices(this.positionSource.map(row => row.security)),
      quotes => {
        this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear(); this.openPriceByTicker.clear();
        for (const quote of quotes) {
          const epoch = this.toPriceEpoch(quote?.asOf);
          const price = Number(quote?.price);
          if (!quote?.ticker || quote.price == null || !Number.isFinite(price) || price <= 0 ||
              epoch == null || Date.now() - epoch > 60000 || epoch - Date.now() > 5000) continue;
          const ticker = String(quote.ticker).trim().toUpperCase();
          this.marketPriceByTicker.set(ticker, price); this.marketPriceAsOfByTicker.set(ticker, epoch);
          if (quote.openPrice != null && Number.isFinite(Number(quote.openPrice)) && Number(quote.openPrice) > 0)
            this.openPriceByTicker.set(ticker, Number(quote.openPrice));
        }
        this.refreshValuation(all);
      });
    const snapshot = new SnapshotPoll<Position>(
      () => { this.snapshotAvailable = false; return (all ? this.tradeService.getAllPositions() : this.tradeService.getPositions(account)).pipe(tap({
        next: () => { this.snapshotAvailable = true; }, error: () => { this.snapshotAvailable = false; }
      })); },
      rows => {
        this.positionSource = rows.filter(row => row && ids.has(Number((row as any).accountId ?? (row as any).accountid)));
        if (!rows.length && !this.snapshotAvailable) {
          this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear(); this.openPriceByTicker.clear();
        }
        this.refreshValuation(all); this.isPending = false; this.quoteSnapshot?.refresh();
      });
    this.settlementSnapshot = snapshot;
    for (const id of ids) this.socketUnSubscribeFns.push(
      this.tradeFeed.subscribeSettlement(`/accounts/${id}/positions`, () => snapshot.refresh()));
    const connection = this.tradeFeed.connectionState$.subscribe(state => {
      if (state === 'connected') { snapshot.refresh(); this.quoteSnapshot?.refresh(); }
    });
    this.socketUnSubscribeFns.push(() => connection.unsubscribe());
  }

  private refreshValuation(all: boolean) {
    this.positions = all ? this.mergePositionsBySecurity(this.positionSource)
      : this.positionSource.map(row => this.recomputePosition(row));
    this.setGridRowData(this.positions); this.emitSummary();
  }

  private refreshAllAccountsPositions() { this.settlementSnapshot?.refresh(); }

  private currentQuote(security: string): number | null {
    const epoch = this.marketPriceAsOfByTicker.get(security);
    if (epoch == null || Date.now() - epoch > 60000 || epoch - Date.now() > 5000) return null;
    return this.marketPriceByTicker.get(security) ?? null;
  }
''')
    source = replace_once(source, '  private clearSubscriptions() {', '''  private clearSubscriptions() {
    this.quoteSnapshot?.dispose(); this.quoteSnapshot = undefined;''')
    source = replace_once(source, '''    this.priceStreamUnsubscribeFn?.();
  }

  private updateMarketPrice''', '''    this.priceStreamUnsubscribeFn?.();
    this.snapshotAvailable = false; this.positionSource = []; this.positions = [];
    this.setGridRowData([]); this.emitSummary();
  }

  private updateMarketPrice''')
    source = replace_once(source, '      const openPrice = Number(this.openPriceByTicker.get(row.security) ?? row.openPrice ?? averageCostBasis);', '      const openPrice = this.openPriceByTicker.get(row.security) ?? null;')
    source = replace_once(source, '      const marketPrice = Number(this.marketPriceByTicker.get(row.security) ?? averageCostBasis);', '      const marketPrice = this.currentQuote(row.security);')
    source = replace_once(source, '      const marketValue = row.quantity * marketPrice;\n      const pnl = marketValue - row.costBasisValue;', '      const marketValue = marketPrice == null ? null : row.quantity * marketPrice;\n      const pnl = marketValue == null ? null : marketValue - row.costBasisValue;')
    source = replace_once(source, '    const openPrice = Number(position.openPrice ?? this.openPriceByTicker.get(security) ?? averageCostBasis);', '    const openPrice = this.openPriceByTicker.get(security) ?? null;')
    source = replace_once(source, '    const marketPrice = Number(position.marketPrice ?? this.marketPriceByTicker.get(security) ?? averageCostBasis);', '    const marketPrice = this.currentQuote(security);')
    source = replace_once(source, '    const marketValue = quantity * marketPrice;', '    const marketValue = marketPrice == null ? null : quantity * marketPrice;')
    source = replace_once(source, '    const pnl = marketValue - costBasisValue;', '    const pnl = marketValue == null ? null : marketValue - costBasisValue;')
    source = section(source, '  private emitSummary() {', '  private applySecurityFilter()', '''  private emitSummary() {
    const totals: PortfolioSummary = { totalMarketValue: 0, totalCostBasis: 0, totalPnl: 0 };
    for (const row of this.positions) {
      totals.totalCostBasis += Number(row.costBasisValue);
      totals.totalMarketValue += row.marketValue == null ? Number.NaN : Number(row.marketValue);
      totals.totalPnl += row.pnl == null ? Number.NaN : Number(row.pnl);
    }
    if (!this.snapshotAvailable) {
      totals.totalCostBasis = Number.NaN; totals.totalMarketValue = Number.NaN; totals.totalPnl = Number.NaN;
    }
    this.summaryChange.emit(totals);
  }
''')
    source = replace_once(source, '  private formatMarketPrice(value: any, openPrice: any): string {', '''  private formatMarketPrice(value: any, openPrice: any): string {
    if (value == null) return 'Price unavailable';
    if (openPrice == null) return this.formatCurrency(value);''')
    for marker, guard in (
        ('  private getMarketPriceCellStyle(value: any, openPrice: any): { [key: string]: string } {', 'value == null || openPrice == null'),
        ('  private getPositionValueCellStyle(marketValue: any, costBasisValue: any): { [key: string]: string } {', 'marketValue == null || costBasisValue == null'),
        ('  private getPnlCellStyle(value: any): { [key: string]: string } {', 'value == null'),
    ):
        source = replace_once(source, marker, marker+'\n    if ('+guard+') return {};')
    return source


def trade(source):
    source = replace_once(source, "import { Subject } from 'rxjs';", "import { Subject, Subscription } from 'rxjs';")
    source = section(source, '    allAccountsSummary: PortfolioSummary = {', '    private account =', '''    selectedOrderSecurity = '';
    private readonly initialRequests = new Subscription();
    summaryValue(value: number): string | null { return Number.isFinite(value) ? null : 'Unavailable'; }
''')
    source = replace_once(source, '        this.accountService.getAccounts().subscribe((accounts) => {', '        this.initialRequests.add(this.accountService.getAccounts().subscribe((accounts) => {')
    source = section(source, '            console.log(this.accounts);', '\n    onAccountChange(', '''        }));
        this.initialRequests.add(this.symbolService.getStocks().subscribe((stocks) => this.stocks = stocks));
    }
''')
    source = replace_once(source, '        this.portfolioSummary = this.isAllAccountsSelected ? this.allAccountsSummary : summary;', '        this.portfolioSummary = summary;')
    source = replace_once(source, "    setBlotterMode(mode: 'trades' | 'orders') {", """    setBlotterMode(mode: 'trades' | 'orders') {
        if (mode !== this.activeBlotter) this.onSummaryChange({ totalMarketValue: Number.NaN, totalCostBasis: Number.NaN, totalPnl: Number.NaN });""")
    source = replace_once(source, '    private setAccount(account: Account) {', '''    private setAccount(account: Account) {
        if (account.id !== 0 && !this.accountIds.includes(account.id)) return;''')
    # Loading/scope switches are unknown, not zero-valued portfolios.
    source = source.replace('totalMarketValue: 0,', 'totalMarketValue: Number.NaN,').replace('totalCostBasis: 0,', 'totalCostBasis: Number.NaN,').replace('totalPnl: 0', 'totalPnl: Number.NaN')
    start = source.index('    ngOnDestroy(): void {')
    source = source[:start] + '''    ngOnDestroy(): void {
        this.initialRequests.unsubscribe(); this.modalRef?.hide();
        this.accounts = []; this.realAccounts = []; this.accountIds = []; this.accountNameById = {};
        this.accountModel = undefined; this.stocks = [];
        this.onSummaryChange({ totalMarketValue: Number.NaN, totalCostBasis: Number.NaN, totalPnl: Number.NaN });
    }
}
'''
    # Only relevant on the pinned source before the parent disables direct booking.
    source = source.replace('            this.loadAllPositions();\n', '')
    return source


def apply(target):
    app = Path(target)/'main/app/trade'
    path = app/'position-blotter/position-blotter.component.ts'
    path.write_text(positions(path.read_text()))
    path = app/'trade.component.ts'; path.write_text(trade(path.read_text()))
    path = app/'trade.component.html'; html = path.read_text()
    start = html.index('    <div class="row mb-3">')
    end = html.index('    <div class="row mb-3">', start+1)
    html = html[:start] + '''    <p class="text-muted small">Totals cover the selected account scope in the Trades / Positions tab. Positions and quotes refresh every two seconds.
        Market value and P&amp;L are unavailable when quotes are missing or over 60 seconds old.</p>
\n''' + html[end:]
    for field in ('totalCostBasis', 'totalMarketValue', 'totalPnl'):
        old = "{{ accountSummary."+field+" | currency:'USD':'symbol':'1.2-2' }}"
        new = "{{ summaryValue(accountSummary."+field+") || (accountSummary."+field+" | currency:'USD':'symbol':'1.2-2') }}"
        html = replace_once(html, old, new)
    html = replace_once(html, "accountSummary.totalPnl >= 0 ? 'alert-success' : 'alert-danger'", "summaryValue(accountSummary.totalPnl) ? 'alert-secondary' : (accountSummary.totalPnl >= 0 ? 'alert-success' : 'alert-danger')")
    path.write_text(html)
