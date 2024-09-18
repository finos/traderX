import { ColDef, GridApi, GridReadyEvent, Module } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { Position, StockPrice } from 'main/app/model/trade.model';
import { PositionService } from 'main/app/service/position.service';
import { PriceService } from 'main/app/service/price.service';
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
  positions: any = [];
  gridApi: GridApi;
  socketUnSubscribeFn: Function;
  marketValueUnSubscribeFn: Function;
  title = 'Closed Positions';

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY'
    },
    {
      headerName: 'P & L',
      field: 'value'
    },
    {
      headerName: 'UNIT PRICE',
      field: 'unitPrice',
      enableCellChangeFlash: true
    }
  ];

  constructor(private tradeService: PositionService,
    private tradeFeed: TradeFeedService,
    private priceService: PriceService) { }

  ngOnChanges(change: SimpleChanges) {
    console.log('Position blotter changes...', change);
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;

      this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
        console.log('Closed Position blotter tradeService feed...', positions);
        this.positions = positions.filter((p: Position) => p.quantity === 0);
        this.priceService.getAccountPrices(accountId, undefined).subscribe((prices: StockPrice[]) => {
          prices.forEach((price) => {
            let position = this.positions.find((p: Position) =>
              p.security === price.ticker);
            if (position) {
              position = Object.assign(position, { unitPrice: price.price });
              this.update(position);
            }
          });
        });
      });


      this.socketUnSubscribeFn?.();
      this.socketUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, (data: any) => {
        console.log('Position blotter websocket feed...', data);
        if (data.quantity === 0) {
          this.update(data);
        }
      });

      this.marketValueUnSubscribeFn?.();
      this.marketValueUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/prices`, (data: StockPrice[]) => {
        console.log('Market value feed...', data);
        this.updateMarketValues(data);
      });
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
