import { ColDef, GridApi, GridReadyEvent, GetRowIdParams } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { Position } from 'main/app/model/trade.model';
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
  positions$: Observable<Position[]>;
  positions: any = [];
  gridApi: GridApi;
  pendingPosition: any[] = [];
  isPending = true;
  socketUnSubscribeFn: Function;

  columnDefs: ColDef[] = [
    {
      field: 'security',
      headerName: 'SECURITY'
    },
    {
      headerName: 'QUANTITY',
      field: 'quantity',
      enableCellChangeFlash: true
    }
  ];

  constructor(private tradeService: PositionService,
    private tradeFeed: TradeFeedService) { }

  ngOnChanges(change: SimpleChanges) {
    if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
      const accountId = change.account.currentValue.id;
      this.isPending = true;

      this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
        this.positions = positions;
        this.processPendingPositions();
      }, () => {
        this.isPending = false;
      });


      this.socketUnSubscribeFn?.();
      this.socketUnSubscribeFn = this.tradeFeed.subscribe(`/accounts/${accountId}/positions`, (data: any) => {
        console.log('Position blotter feed...', data);
        this.updatePosition(data);
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
    const rowId = `Position-${data.security}`;
    const row = this.gridApi.getRowNode(rowId);
    let positionData;
    if (row) {
      positionData = {
        update: [Object.assign(row.data, { quantity: data.quantity })]
      };
    } else {
      positionData = {
        add: [{
          accountid: data.accountid,
          quantity: data.quantity,
          security: data.security,
          updated: data.updated
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

  getRowId(params: GetRowIdParams<any>):string {
    return `Position-${params.data.security}`;
  }

  ngOnDestroy() {
    this.socketUnSubscribeFn?.();
  }

}
