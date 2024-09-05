import { ColDef, GridApi, GridReadyEvent, Module } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { Position, StockPrice } from 'main/app/model/trade.model';
import { Observable } from 'rxjs';
import { PriceService } from 'main/app/service/price.service';

@Component({
  selector: 'app-closed-position-blotter',
  templateUrl: '../position-blotter/position-blotter.component.html',
  styleUrls: ['../position-blotter/position-blotter.component.scss']
})
export class ClosedPositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  @Input() accountPositions: Position[];
  gridApi: GridApi;
  marketValueUnSubscribeFn: Function;
  title = 'Closed Positions';
  positions$: Observable<Position[]>;
  positions: Position[] = [];

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

  constructor(private priceService: PriceService) { }

  ngOnChanges(change: SimpleChanges) {
    console.log('Position blotter changes...', change);
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      console.log('Closed Position blotter', this.accountPositions);
      this.positions = this.accountPositions?.filter((p) => p.quantity === 0);
      this.priceService.getAccountPrices(accountId).subscribe((prices: StockPrice[]) => {
        prices.forEach((price) => {
          let position = this.positions?.find((p: Position) =>
            p.security === price.ticker);
          if (position) {
            position = Object.assign(position, { unitPrice: price.price });
            this.update(position);
          }
        });
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

  onGridReady(params: GridReadyEvent) {
    console.log('position blotter is ready...');
    this.gridApi = params.api;
  }

  getRowNodeId(data: Position) {
    return data.security;
  }

  ngOnDestroy() {
    this.marketValueUnSubscribeFn?.();
  }
}
