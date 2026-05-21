import { ColDef, GridApi, GridReadyEvent, GetRowIdParams, RowClickedEvent } from 'ag-grid-community';
import { Component, EventEmitter, Input, OnChanges, OnDestroy, Output, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PortfolioSummary, Position, PriceTick } from 'main/app/model/trade.model';
import { PositionService } from 'main/app/service/position.service';
import { Observable } from 'rxjs';
import { TradeFeedService } from 'main/app/service/trade-feed.service';
import { PriceSnapshotService } from 'main/app/service/price-snapshot.service';

@Component({
    standalone: false,
  selector: 'app-position-blotter',
  templateUrl: './position-blotter.component.html',
  styleUrls: ['./position-blotter.component.scss']
})
export class PositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  @Input() allAccountsMode = false;
  @Input() accountIds: number[] = [];
  @Input() securityFilter = '';
  @Output() summaryChange = new EventEmitter<PortfolioSummary>();
  @Output() securitySelected = new EventEmitter<string>();
  positions$: Observable<Position[]>;
  positions: any = [];
  gridApi: GridApi;
  pendingPosition: any[] = [];
  isPending = true;
  socketUnSubscribeFns: Function[] = [];
  priceStreamUnsubscribeFn?: Function;
  private readonly marketPriceByTicker = new Map<string, number>();
  private readonly marketPriceAsOfByTicker = new Map<string, number>();
  private readonly openPriceByTicker = new Map<string, number>();

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY'
    },
    {
      headerName: 'QUANTITY',
      field: 'quantity',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatInteger(value)
    },
    {
      headerName: 'AVG COST',
      field: 'averageCostBasis',
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatCurrency(value)
    },
    {
      headerName: 'OPEN',
      field: 'openPrice',
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatCurrency(value)
    },
    {
      headerName: 'MKT PRICE',
      field: 'marketPrice',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      cellStyle: ({ value, data }) => this.getMarketPriceCellStyle(value, data?.openPrice),
      valueFormatter: ({ value, data }) => this.formatMarketPrice(value, data?.openPrice)
    },
    {
      headerName: 'POSITION VALUE',
      field: 'marketValue',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      cellStyle: ({ data }) => this.getPositionValueCellStyle(data?.marketValue, data?.costBasisValue),
      valueFormatter: ({ value }) => this.formatCurrency(value)
    },
    {
      headerName: 'P&L',
      field: 'pnl',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      cellStyle: ({ value }) => this.getPnlCellStyle(value),
      valueFormatter: ({ value }) => this.formatCurrency(value)
    }
  ];

  constructor(
    private tradeService: PositionService,
    private tradeFeed: TradeFeedService,
    private priceSnapshots: PriceSnapshotService
  ) {
    this.getRowId = this.getRowId.bind(this);
  }

  ngOnChanges(change: SimpleChanges) {
    const scopeChanged = !!change.account || !!change.allAccountsMode || !!change.accountIds;
    if (change.securityFilter && !scopeChanged) {
      this.applySecurityFilter();
    }
    if (scopeChanged) {
      this.loadScope();
    }
  }

  processPendingPositions() {
    this.pendingPosition.forEach((position: any) => this.update(position));
    this.pendingPosition = [];
    this.isPending = false;
  }

  updatePosition(data: any) {
    if (this.allAccountsMode) {
      this.refreshAllAccountsPositions();
      return;
    }
    if (this.isPending) {
      this.pendingPosition.push(data);
    } else {
      this.update(this.recomputePosition(data));
    }
  }

  update(data: any) {
    if (!this.gridApi) {
      this.pendingPosition.push(data);
      return;
    }
    const security = data?.security;
    if (!security) {
      return;
    }

    const recomputed = this.recomputePosition(data);
    const row = this.gridApi.getRowNode(this.toRowId(security));
    let positionData;
    if (row) {
      positionData = {
        update: [Object.assign(row.data, recomputed)]
      };
    } else {
      positionData = {
        add: [{
          accountid: recomputed.accountid ?? recomputed.accountId,
          accountId: recomputed.accountId ?? recomputed.accountid,
          quantity: recomputed.quantity,
          security,
          averageCostBasis: recomputed.averageCostBasis,
          openPrice: recomputed.openPrice,
          marketPrice: recomputed.marketPrice,
          marketValue: recomputed.marketValue,
          costBasisValue: recomputed.costBasisValue,
          pnl: recomputed.pnl,
          updated: recomputed.updated
        }],
        addIndex: 0
      };
    }
    this.gridApi.applyTransaction(positionData);
    this.emitSummary();
  }

  onGridReady(params: GridReadyEvent) {
    console.log('position blotter is ready...');
    this.gridApi = params.api;
    this.applySecurityFilter();
    this.gridApi.sizeColumnsToFit();
    this.emitSummary();
  }

  onRowClicked(event: RowClickedEvent) {
    const security = String((event?.data as any)?.security || '').trim().toUpperCase();
    if (!security) {
      return;
    }
    this.securitySelected.emit(security);
  }

  getRowId(params: GetRowIdParams<any>):string {
    if (!params?.data?.security) {
      return 'Position-unknown';
    }
    return this.toRowId(params.data.security);
  }

  private toRowId(security: string): string {
    return `Position-${security}`;
  }

  ngOnDestroy() {
    this.clearSubscriptions();
    this.priceStreamUnsubscribeFn?.();
  }

  private updateMarketPrice(tick: PriceTick) {
    if (!tick?.ticker || tick.price == null) {
      return;
    }
    if (!this.applyMarketPriceUpdate(tick.ticker, tick.price, tick.asOf ?? null)) {
      return;
    }
    if (tick.openPrice != null && Number.isFinite(Number(tick.openPrice))) {
      this.openPriceByTicker.set(String(tick.ticker || '').trim().toUpperCase(), Number(tick.openPrice));
    }
    if (!this.gridApi) {
      return;
    }
    const normalizedTicker = String(tick.ticker || '').trim().toUpperCase();
    const row = this.gridApi.getRowNode(this.toRowId(normalizedTicker));
    if (!row) {
      return;
    }
    this.update(Object.assign({}, row.data, {
      marketPrice: Number(tick.price),
      openPrice: this.openPriceByTicker.get(normalizedTicker),
      security: normalizedTicker
    }));
  }

  private loadScope() {
    this.clearSubscriptions();
    this.isPending = true;
    this.marketPriceByTicker.clear();
    this.marketPriceAsOfByTicker.clear();
    this.openPriceByTicker.clear();
    this.pendingPosition = [];

    this.priceStreamUnsubscribeFn?.();
    this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (data: PriceTick) => {
      this.updateMarketPrice(data);
    });

    if (this.allAccountsMode) {
      this.refreshAllAccountsPositions();
      for (const accountId of this.accountIds) {
        const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, () => {
          this.refreshAllAccountsPositions();
        });
        this.socketUnSubscribeFns.push(unSub);
      }
      return;
    }

    const accountId = this.account?.id;
    if (!accountId || accountId <= 0) {
      this.positions = [];
      this.isPending = false;
      this.emitSummary();
      return;
    }

    this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
      this.positions = (positions ?? []).map((position: any) => this.recomputePosition(position));
      this.processPendingPositions();
      this.bootstrapSnapshotPrices(this.positions.map((position: any) => position.security));
    }, () => {
      this.isPending = false;
    });

    const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, (data: any) => {
      console.log('Position blotter feed...', data);
      this.updatePosition(data);
    });
    this.socketUnSubscribeFns.push(unSub);
  }

  private refreshAllAccountsPositions() {
    this.tradeService.getAllPositions().subscribe((positions: Position[]) => {
      const merged = this.mergePositionsBySecurity(positions ?? []);
      this.positions = merged;
      if (this.gridApi) {
        this.setGridRowData(merged);
      }
      this.isPending = false;
      this.emitSummary();
      this.bootstrapSnapshotPrices(merged.map((position: any) => position.security));
    }, () => {
      this.isPending = false;
    });
  }

  private bootstrapSnapshotPrices(tickers: string[]): void {
    this.priceSnapshots.getPrices(tickers).subscribe((snapshots) => {
      let changed = false;
      for (const snapshot of snapshots || []) {
        if (!snapshot || !snapshot.ticker || snapshot.price == null) {
          continue;
        }
        if (this.applyMarketPriceUpdate(snapshot.ticker, snapshot.price, snapshot.asOf ?? null)) {
          changed = true;
        }
        if (snapshot.openPrice != null && Number.isFinite(Number(snapshot.openPrice))) {
          this.openPriceByTicker.set(String(snapshot.ticker || '').trim().toUpperCase(), Number(snapshot.openPrice));
        }
      }
      if (!changed) {
        return;
      }
      if (this.allAccountsMode) {
        this.refreshAllAccountsPositions();
      } else {
        this.positions = (this.positions || []).map((position: any) => this.recomputePosition(position));
        this.setGridRowData(this.positions);
        this.emitSummary();
      }
    });
  }

  private applyMarketPriceUpdate(ticker: string, price: number, asOf: string | null): boolean {
    const normalizedTicker = String(ticker || '').trim().toUpperCase();
    const numericPrice = Number(price);
    if (!normalizedTicker || !Number.isFinite(numericPrice)) {
      return false;
    }

    const nextEpoch = this.toPriceEpoch(asOf);
    const currentEpoch = this.marketPriceAsOfByTicker.get(normalizedTicker);
    if (nextEpoch != null) {
      if (currentEpoch != null && nextEpoch < currentEpoch) {
        return false;
      }
      this.marketPriceAsOfByTicker.set(normalizedTicker, nextEpoch);
    } else if (currentEpoch != null) {
      return false;
    }

    this.marketPriceByTicker.set(normalizedTicker, numericPrice);
    return true;
  }

  private mergePositionsBySecurity(positions: Position[]): any[] {
    const grouped = new Map<string, {
      security: string;
      quantity: number;
      costBasisValue: number;
      averageCostBasis: number;
      openPrice: number;
      marketPrice: number;
      marketValue: number;
      pnl: number;
      updated: any;
    }>();

    for (const rawPosition of positions) {
      const recomputed = this.recomputePosition(rawPosition);
      const security = recomputed?.security;
      if (!security) {
        continue;
      }
      if (!grouped.has(security)) {
        grouped.set(security, {
          security,
          quantity: 0,
          costBasisValue: 0,
          averageCostBasis: 0,
          openPrice: 0,
          marketPrice: 0,
          marketValue: 0,
          pnl: 0,
          updated: recomputed.updated
        });
      }
      const row = grouped.get(security)!;
      const quantity = Number(recomputed.quantity ?? 0);
      const costBasisValue = Number(recomputed.costBasisValue ?? 0);
      const openPrice = Number(recomputed.openPrice ?? 0);
      row.quantity += quantity;
      row.costBasisValue += costBasisValue;
      row.openPrice = openPrice || row.openPrice;
      row.updated = recomputed.updated ?? row.updated;
    }

    const rows = Array.from(grouped.values()).map((row) => {
      const averageCostBasis = row.quantity !== 0 ? row.costBasisValue / row.quantity : 0;
      const openPrice = Number(this.openPriceByTicker.get(row.security) ?? row.openPrice ?? averageCostBasis);
      const marketPrice = Number(this.marketPriceByTicker.get(row.security) ?? averageCostBasis);
      const marketValue = row.quantity * marketPrice;
      const pnl = marketValue - row.costBasisValue;
      return {
        security: row.security,
        quantity: row.quantity,
        averageCostBasis,
        openPrice,
        marketPrice,
        marketValue,
        costBasisValue: row.costBasisValue,
        pnl,
        updated: row.updated
      };
    });

    rows.sort((a, b) => String(a.security).localeCompare(String(b.security)));
    return rows;
  }

  private clearSubscriptions() {
    for (const unSub of this.socketUnSubscribeFns) {
      unSub?.();
    }
    this.socketUnSubscribeFns = [];
  }

  private setGridRowData(rows: any[]) {
    if (!this.gridApi) {
      return;
    }
    if (typeof (this.gridApi as any).setGridOption === 'function') {
      (this.gridApi as any).setGridOption('rowData', rows);
    } else if (typeof (this.gridApi as any).setRowData === 'function') {
      (this.gridApi as any).setRowData(rows);
    }
    this.applySecurityFilter();
    this.gridApi.sizeColumnsToFit();
  }

  private recomputePosition(position: any): any {
    if (!position || !position.security) {
      return position;
    }
    const security = String(position.security || '').trim().toUpperCase();
    const quantity = Number(position.quantity ?? 0);
    const averageCostBasis = Number(position.averageCostBasis ?? position.averagecostbasis ?? 0);
    const openPrice = Number(position.openPrice ?? this.openPriceByTicker.get(security) ?? averageCostBasis);
    const marketPrice = Number(position.marketPrice ?? this.marketPriceByTicker.get(security) ?? averageCostBasis);
    const marketValue = quantity * marketPrice;
    const costBasisValue = quantity * averageCostBasis;
    const pnl = marketValue - costBasisValue;

    return Object.assign({}, position, {
      security,
      quantity,
      averageCostBasis,
      openPrice,
      marketPrice,
      marketValue,
      costBasisValue,
      pnl
    });
  }

  private toPriceEpoch(asOf: string | null | undefined): number | null {
    if (!asOf) {
      return null;
    }
    const ts = new Date(asOf).getTime();
    return Number.isFinite(ts) ? ts : null;
  }

  private emitSummary() {
    if (!this.gridApi) {
      return;
    }

    const totals: PortfolioSummary = {
      totalMarketValue: 0,
      totalCostBasis: 0,
      totalPnl: 0
    };

    this.gridApi.forEachNode((node) => {
      if (!node.data?.security) {
        return;
      }
      totals.totalMarketValue += Number(node.data.marketValue ?? 0);
      totals.totalCostBasis += Number(node.data.costBasisValue ?? 0);
      totals.totalPnl += Number(node.data.pnl ?? 0);
    });

    this.summaryChange.emit(totals);
  }

  private applySecurityFilter() {
    if (!this.gridApi) {
      return;
    }
    const filterValue = String(this.securityFilter || '').trim().toUpperCase();
    if (typeof (this.gridApi as any).setGridOption === 'function') {
      (this.gridApi as any).setGridOption('quickFilterText', filterValue);
      return;
    }
    if (typeof (this.gridApi as any).setQuickFilter === 'function') {
      (this.gridApi as any).setQuickFilter(filterValue);
    }
  }

  private formatCurrency(value: any): string {
    if (value == null || value === '') {
      return '-';
    }
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
      return '-';
    }
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(numeric);
  }

  private formatInteger(value: any): string {
    if (value == null || value === '') {
      return '-';
    }
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
      return '-';
    }
    return new Intl.NumberFormat('en-US', {
      maximumFractionDigits: 0
    }).format(numeric);
  }

  private formatMarketPrice(value: any, openPrice: any): string {
    const market = Number(value);
    if (!Number.isFinite(market)) {
      return '-';
    }
    const open = Number(openPrice);
    if (!Number.isFinite(open)) {
      return this.formatCurrency(market);
    }
    const marker = market > open ? '▲' : market < open ? '▼' : '■';
    return `${marker} ${this.formatCurrency(market)}`;
  }

  private getMarketPriceCellStyle(value: any, openPrice: any): { [key: string]: string } {
    const market = Number(value);
    const open = Number(openPrice);
    if (!Number.isFinite(market) || !Number.isFinite(open)) {
      return {};
    }
    if (market < open) {
      return {
        color: '#8B0000',
        backgroundColor: '#FFE4EC',
        fontWeight: '700'
      };
    }
    if (market > open) {
      return {
        color: '#006400',
        backgroundColor: '#E6F4EA',
        fontWeight: '700'
      };
    }
    return {
      color: '#1F2937',
      backgroundColor: '#F3F4F6',
      fontWeight: '700'
    };
  }

  private getPositionValueCellStyle(marketValue: any, costBasisValue: any): { [key: string]: string } {
    const market = Number(marketValue);
    const cost = Number(costBasisValue);
    if (!Number.isFinite(market) || !Number.isFinite(cost)) {
      return {};
    }
    if (market < cost) {
      return {
        color: '#8B0000',
        backgroundColor: '#FFE4EC',
        fontWeight: '700'
      };
    }
    if (market > cost) {
      return {
        color: '#006400',
        backgroundColor: '#E6F4EA',
        fontWeight: '700'
      };
    }
    return {
      color: '#1F2937',
      backgroundColor: '#F3F4F6',
      fontWeight: '700'
    };
  }

  private getPnlCellStyle(value: any): { [key: string]: string } {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) {
      return { fontWeight: '700' };
    }
    if (numeric < 0) {
      return {
        fontWeight: '700',
        color: '#8B0000',
        backgroundColor: '#FFE4EC'
      };
    }
    if (numeric > 0) {
      return {
        fontWeight: '700',
        color: '#006400',
        backgroundColor: '#E6F4EA'
      };
    }
    return {
      fontWeight: '700',
      color: '#1F2937',
      backgroundColor: '#F3F4F6'
    };
  }
}
