import { ColDef, GridApi, GridReadyEvent, Module } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { Position, StockPrice } from 'main/app/model/trade.model';
import { PositionService } from 'main/app/service/position.service';
import { Observable } from 'rxjs';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

@Component({
  selector: 'app-closed-position-blotter',
  templateUrl: '../position-blotter/position-blotter.component.html',
  styleUrls: ['../position-blotter/position-blotter.component.scss']
})
export class ClosedPositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  positions$: Observable<Position[]>;
  filteredPositions: any = [];
  gridApi: GridApi;
  pendingPosition: any[] = [];
  isPending = true;
  socketUnSubscribeFn: Function;
  marketValueUnSubscribeFn: Function;
  title = 'Closed Positions';

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY'
    },
    {
      headerName: 'VALUE',
      field: 'value'
    },
    {
      headerName: 'UNIT PRICE',
      field: 'unitPrice',
      enableCellChangeFlash: true
    }
  ];

  constructor(private tradeService: PositionService,
    private tradeFeed: TradeFeedService) { }

  ngOnChanges(change: SimpleChanges) {
    console.log('Position blotter changes...', change);
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      this.isPending = true;

      this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
        console.log('Closed Position blotter tradeService feed...', positions);
        this.filteredPositions = positions.filter((p: Position) => p.quantity === 0);
        this.processPendingPositions();
      }, () => {
        this.isPending = false;
      });


      this.socketUnSubscribeFn?.();
      this.socketUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, (data: any) => {
        console.log('Position blotter websocket feed...', data);
        if (data.quantity === 0) {
          this.updatePosition(data);
        }
      });

      this.marketValueUnSubscribeFn?.();
      this.marketValueUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/prices`, (data: StockPrice[]) => {
        console.log('Market value feed...', data);
        this.updateMarketValues(data);
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
      this.update(data);
    }
  }

  update(data: any) {
    const row = this.gridApi.getRowNode(data.security);
    let positionData;
    if (row) {
      positionData = {
        update: [Object.assign(row.data, { quantity: data.quantity, value: data.value })],
      };
    } else {
      positionData = {
        add: [{
          accountid: data.accountid,
          security: data.security,
          updated: data.updated,
          value: data.value
        }],
        addIndex: 0
      };
    }
    this.gridApi.applyTransaction(positionData);
  }

  updateMarketValues(data: StockPrice[]) {
    data.forEach((price) => {
      const row = this.gridApi.getRowNode(price.ticker);
      if (row) {
        const positionData = {
          update: [Object.assign(row.data, { unitPrice: price.price })],
        };
        this.gridApi.applyTransaction(positionData);
      }
    });
  }

  onGridReady(params: GridReadyEvent) {
    console.log('position blotter is ready...');
    this.gridApi = params.api;
  }

  getRowNodeId(data: Position) {
    return data.security;
  }

  ngOnDestroy() {
    this.socketUnSubscribeFn?.();
    this.marketValueUnSubscribeFn?.();
  }
}
