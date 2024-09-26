import { ColDef, GridApi, GridReadyEvent, Module } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { Position, StockPrice, TradeInterval, TradePointInTime } from 'main/app/model/trade.model';
import { Observable } from 'rxjs';
import { PriceService } from 'main/app/service/price.service';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

@Component({
  selector: 'app-closed-position-blotter',
  templateUrl: '../position-blotter/position-blotter.component.html',
  styleUrls: ['../position-blotter/position-blotter.component.scss']
})
export class ClosedPositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  @Input() interval?: TradeInterval;
  @Input() priceDate?: Date;
  gridApi: GridApi;
  marketValueUnSubscribeFn: Function;
  title = 'Closed Positions';
  height = '150px';
  width = '100%';
  positions: Position[] = [];

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY',
      width: 110
    },
    {
      headerName: 'P & L',
      field: 'value',
      width: 130
    },
    {
      headerName: 'UNIT PRICE',
      field: 'unitPrice',
      enableCellChangeFlash: true,
      width: 130
    },
    {
      headerName: 'CALCULATION',
      field: 'calculation',
      width: 250
    }
  ];

  constructor(private priceService: PriceService,
    private tradeFeed: TradeFeedService) { }

  ngOnChanges(change: SimpleChanges) {
    console.log('Position blotter changes...', change);
    if (change.account?.currentValue &&
        change.account.currentValue !== change.account.previousValue) {
      this.account = change.account.currentValue;
    }
    if (change.interval?.currentValue &&
        change.interval.currentValue !== change.interval.previousValue) {
      this.interval = change.interval.currentValue;
    }
    if (change.priceDate &&
        change.priceDate.currentValue !== change.priceDate.previousValue) {
      this.priceDate = change.priceDate.currentValue;
    }
    const accountId = this.account?.id || 52355;
    const interval = this.interval;

    console.log('Closed Position blotter', accountId, interval);
    this.priceService.getPositions(accountId, interval).subscribe((positions: Position[]) => {
      this.positions = positions.filter((p) => p.quantity <= 0);
      console.log('Closed Position blotter', this.positions);
      this.priceService.getAccountPrices(accountId, this.priceDate).subscribe((prices: StockPrice[]) => {
        prices.forEach((price) => {
          let position = this.positions?.find((p: Position) =>
            p.security === price.ticker);
          if (position) {
            position = Object.assign(position, { unitPrice: price.price });
            this.update(position);
          }
        });
      });
      this.marketValueUnSubscribeFn?.();
      if (this.priceDate === undefined) {
        this.marketValueUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/prices`, (data: StockPrice[]) => {
            console.log('Report Closed Position Market value feed...', data);
            this.updateUnitPrice(data);
        });
      }
    });
  }

  update(data: any) {
    const row = this.gridApi.getRowNode(data.security);
    let positionData;
    if (row) {
      positionData = {
        update: [Object.assign(row.data, { quantity: data.quantity, value: data.value, calculation: data.calculation  })],
      };
    } else {
      positionData = {
        add: [{
          accountid: data.accountid,
          security: data.security,
          updated: data.updated,
          value: data.value,
          calculation: data.calculation
        }],
        addIndex: 0
      };
    }
    this.gridApi.applyTransaction(positionData);
  }

  updateUnitPrice(data: StockPrice[]) {
    data.forEach((price) => {
      let position = this.positions?.find((p: Position) =>
        p.security === price.ticker);
      if (position) {
        position = Object.assign(position, { unitPrice: price.price });
        this.update(position);
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

  getRowClass(params: any) {
    if (params.data.value < 0) {
      return 'negative';
    } else if (params.data.value > 0) {
      return 'positive';
    } else {
      return '';
    }
  }

  getRowStyle(params: any) {
    if (params.data.value < 0) {
      return { "background-color": "rgba(226, 2, 2, 0.1)" };
    } else if (params.data.value > 0) {
      return { "background-color": "rgba(2, 226, 2, 0.1)" };
    } else {
      return { "background-color": "rgba(226, 226, 226, 0.1)" };
    }
  }

  ngOnDestroy() {
    this.marketValueUnSubscribeFn?.();
  }
}
