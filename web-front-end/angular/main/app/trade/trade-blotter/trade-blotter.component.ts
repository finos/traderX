import { ColDef, GridApi, GridReadyEvent, GetRowIdParams } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PositionService } from 'main/app/service/position.service';
import { Observable } from 'rxjs';
import { Trade } from '../../model/trade.model';
import { TradeFeedService } from 'main/app/service/trade-feed.service';
import { TradeStateComponent } from './TradeStateComponent';

@Component({
  selector: 'app-trade-blotter',
  templateUrl: 'trade-blotter.component.html'
})
export class TradeBlotterComponent implements OnChanges, OnDestroy {
  trades$: Observable<Trade[]>;
  @Input() account?: Account;
  trades: Trade[] = [];
  gridApi: GridApi;
  pendingTrades: Trade[] = [];
  isPending = true;
  socketUnSubscribeFn: Function;
  columnDefs: ColDef[] = [
    {
      headerName: 'SECURITY',
      field: 'security'
    },
    {
      headerName: 'QUANTITY',
      field: 'quantity'
    },
    {
      headerName: 'SIDE',
      field: 'side'
    },
    {
      headerName: 'STATE',
      field: 'data',
      cellRenderer: TradeStateComponent,
      enableCellChangeFlash: true
    }
  ];

  constructor(
    private tradeFeed: TradeFeedService,
    private tradeService: PositionService
  ) {}

  ngOnChanges(change: SimpleChanges) {
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      this.isPending = true;
      this.tradeService.getTrades(accountId).subscribe((trades: Trade[]) => {
        this.trades = trades;
        this.processPendingTrades();
      });
      this.socketUnSubscribeFn?.();
      this.socketUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/trades`, (data: Trade) => {
        console.log('Trade blotter feed...', data);
        this.updateTrades(data);
      });
    }
  }

  onGridReady(params: GridReadyEvent) {
    console.log('trade blotter is ready...');
    this.gridApi = params.api;
    this.gridApi.sizeColumnsToFit();
  }

  getRowId(params: GetRowIdParams<any>): string {
    return `Trade-${params.data.id}`;
  }

  ngOnDestroy() {
    this.socketUnSubscribeFn?.();
  }

  private processPendingTrades() {
    this.pendingTrades.forEach((tradeUpdate) => this.update(tradeUpdate));
    this.pendingTrades = [];
    this.isPending = false;
  }

  private update(data: Trade) {
    const row = this.gridApi.getRowNode(`Trade-${data.id}`);
    let tradeData;

    if (row) {
      // have to pop/add to allow for complete update
      tradeData = {
        remove: [row.data],
        add: [
          {
            ... data,
            side: this.toTitleCase(data.side),
          }
        ],
        addIndex: 0
      };
    } else {
      tradeData = {
        add: [
          {
            accountid: data.accountid,
            created: data.created,
            id: data.id,
            quantity: data.quantity,
            security: data.security,
            side: this.toTitleCase(data.side),
            state: data.state,
            updated: data.updated
          }
        ],
        addIndex: 0
      };
    }
    this.gridApi.applyTransaction(tradeData);
  }

  private updateTrades(data: Trade) {
    if (this.isPending) {
      this.pendingTrades.push(data);
    } else {
      this.update(data);
    }
  }

  private toTitleCase(str: string): string {
    return str.replace(
      /\w\S*/g,
      text => text.charAt(0).toUpperCase() + text.substring(1).toLowerCase()
    );
  }
}
