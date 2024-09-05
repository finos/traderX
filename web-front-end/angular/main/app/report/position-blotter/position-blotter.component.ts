import { ColDef, GridApi, GridReadyEvent, Module } from 'ag-grid-community';
import { Account } from 'main/app/model/account.model';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Position, StockPrice } from 'main/app/model/trade.model';
import { Observable } from 'rxjs';
import { PriceService } from 'main/app/service/price.service';

@Component({
  selector: 'app-position-blotter',
  templateUrl: './position-blotter.component.html',
  styleUrls: ['./position-blotter.component.scss']
})
export class PositionBlotterComponent implements OnChanges, OnDestroy {
  @Input() account?: Account;
  accountPositions$: Observable<Position[]>;
  @Input() accountPositions: Position[];
  gridApi: GridApi;
  socketUnSubscribeFn: Function;
  marketValueUnSubscribeFn: Function;
  title = 'Positions';
  // positions$: Observable<Position[]>;
  positions: Position[];

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY'
    },
    {
      headerName: 'QUANTITY',
      field: 'quantity',
      enableCellChangeFlash: true
    },
    {
      headerName: 'MONEY IN/OUT',
      field: 'value'
    },
    {
      headerName: 'MARKET VALUE',
      field: 'marketValue',
      enableCellChangeFlash: true
    }
  ];

  constructor(private priceService: PriceService) { }

  ngOnChanges(change: SimpleChanges) {
    console.log('Position blotter changes...', change);
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      this.priceService.getPositions(accountId).subscribe((positions: Position[]) => {
        console.log('Account Positions', positions);
        this.positions = positions.filter((p: Position) => p.quantity > 0);
        console.log('Position blotter', this.positions);
      });

      this.priceService.getAccountPrices(accountId).subscribe((prices: StockPrice[]) => {
        prices.forEach((price) => {
          let position = this.positions.find((p: Position) =>
            p.security === price.ticker);
          if (position) {
            position = Object.assign(position, { marketValue: Math.abs(position.quantity * price.price) });
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
      if (data.quantity === 0) {
        positionData = {
          remove: [{security: data.security}]
        };
      } else {
        positionData = {
          update: [Object.assign(row.data, { quantity: data.quantity, value: data.value })],
        };
      }
    } else {
      positionData = {
        add: [{
          accountid: data.accountid,
          quantity: data.quantity,
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
    this.socketUnSubscribeFn?.();
    this.marketValueUnSubscribeFn?.();
  }

}
