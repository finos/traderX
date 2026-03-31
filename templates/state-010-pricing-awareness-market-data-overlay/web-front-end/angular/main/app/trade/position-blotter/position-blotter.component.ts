import { ColDef, GridApi, GridReadyEvent, GetRowIdParams } from 'ag-grid-community';
import { Component, EventEmitter, Input, OnChanges, OnDestroy, Output, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PortfolioSummary, Position, PriceTick } from 'main/app/model/trade.model';
import { PositionService } from 'main/app/service/position.service';
import { Observable } from 'rxjs';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

@Component({
  selector: 'app-position-blotter',
  templateUrl: './position-blotter.component.html',
  styleUrls: ['./position-blotter.component.scss']
})
export class PositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  @Output() summaryChange = new EventEmitter<PortfolioSummary>();
  positions$: Observable<Position[]>;
  positions: any = [];
  gridApi: GridApi;
  pendingPosition: any[] = [];
  isPending = true;
  socketUnSubscribeFn: Function;
  priceStreamUnsubscribeFn: Function;
  private readonly marketPriceByTicker = new Map<string, number>();

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
      headerName: 'MKT PRICE',
      field: 'marketPrice',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatCurrency(value)
    },
    {
      headerName: 'POSITION VALUE',
      field: 'marketValue',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatCurrency(value)
    },
    {
      headerName: 'P&L',
      field: 'pnl',
      enableCellChangeFlash: true,
      headerClass: 'ag-right-aligned-header',
      cellClass: 'ag-right-aligned-cell',
      valueFormatter: ({ value }) => this.formatCurrency(value)
    }
  ];

  constructor(private tradeService: PositionService,
    private tradeFeed: TradeFeedService) {
    this.getRowId = this.getRowId.bind(this);
  }

  ngOnChanges(change: SimpleChanges) {
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      this.isPending = true;
      this.marketPriceByTicker.clear();

      this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
        this.positions = positions.map((position) => this.recomputePosition(position));
        this.processPendingPositions();
      }, () => {
        this.isPending = false;
      });


      this.socketUnSubscribeFn?.();
      this.socketUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, (data: any) => {
        console.log('Position blotter feed...', data);
        this.updatePosition(data);
      });

      this.priceStreamUnsubscribeFn?.();
      this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (data: PriceTick) => {
        this.updateMarketPrice(data);
      });
    }
  }

  processPendingPositions() {
    this.pendingPosition.forEach((position) => this.update(position));
    this.pendingPosition = [];
    this.isPending = false;
  }

  updatePosition(data: any) {
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
    this.emitSummary();
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
    this.socketUnSubscribeFn?.();
    this.priceStreamUnsubscribeFn?.();
  }

  private updateMarketPrice(tick: PriceTick) {
    if (!tick?.ticker || tick.price == null) {
      return;
    }
    this.marketPriceByTicker.set(tick.ticker, Number(tick.price));
    if (!this.gridApi) {
      return;
    }
    const row = this.gridApi.getRowNode(this.toRowId(tick.ticker));
    if (!row) {
      return;
    }
    this.update(Object.assign({}, row.data, { marketPrice: Number(tick.price), security: tick.ticker }));
  }

  private recomputePosition(position: any): any {
    if (!position || !position.security) {
      return position;
    }
    const quantity = Number(position.quantity ?? 0);
    const averageCostBasis = Number(position.averageCostBasis ?? position.averagecostbasis ?? 0);
    const marketPrice = Number(position.marketPrice ?? this.marketPriceByTicker.get(position.security) ?? averageCostBasis);
    const marketValue = quantity * marketPrice;
    const costBasisValue = quantity * averageCostBasis;
    const pnl = marketValue - costBasisValue;

    return Object.assign({}, position, {
      quantity,
      averageCostBasis,
      marketPrice,
      marketValue,
      costBasisValue,
      pnl
    });
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
      minimumFractionDigits: 3,
      maximumFractionDigits: 3
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
}
