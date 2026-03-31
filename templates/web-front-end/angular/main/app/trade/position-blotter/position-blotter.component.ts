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
  @Input() allAccountsMode = false;
  @Input() accountIds: number[] = [];
  positions$: Observable<Position[]>;
  positions: any = [];
  gridApi: GridApi;
  pendingPosition: any[] = [];
  isPending = true;
  socketUnSubscribeFns: Function[] = [];

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
    private tradeFeed: TradeFeedService) {
    this.getRowId = this.getRowId.bind(this);
  }

  ngOnChanges(change: SimpleChanges) {
    const scopeChanged = !!change.account || !!change.allAccountsMode || !!change.accountIds;
    if (scopeChanged) {
      this.loadScope();
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
    if (!this.gridApi) {
      this.pendingPosition.push(data);
      return;
    }
    const security = data?.security;
    if (!security) {
      return;
    }

    const row = this.gridApi.getRowNode(this.toRowId(security));
    let positionData;
    if (row) {
      positionData = {
        update: [Object.assign(row.data, { quantity: data.quantity, updated: data.updated })]
      };
    } else {
      positionData = {
        add: [{
          accountid: data.accountid ?? data.accountId,
          quantity: data.quantity,
          security,
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
    this.gridApi.sizeColumnsToFit();
  }

  getRowId(params: GetRowIdParams<any>):string {
    return this.toRowId(params.data.security);
  }

  private toRowId(security: string): string {
    return `Position-${security}`;
  }

  ngOnDestroy() {
    this.clearSubscriptions();
  }

  private loadScope() {
    this.clearSubscriptions();
    this.isPending = true;

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
      this.pendingPosition = [];
      this.isPending = false;
      return;
    }

    this.tradeService.getPositions(accountId).subscribe((positions: Position[]) => {
      this.positions = positions ?? [];
      this.processPendingPositions();
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
      this.pendingPosition = [];
      this.isPending = false;
    }, () => {
      this.isPending = false;
    });
  }

  private mergePositionsBySecurity(positions: Position[]): any[] {
    const grouped = new Map<string, any>();
    for (const position of positions) {
      const security = (position as any)?.security;
      if (!security) {
        continue;
      }
      const quantity = Number((position as any).quantity ?? 0);
      const updated = (position as any).updated;
      if (!grouped.has(security)) {
        grouped.set(security, {
          security,
          quantity: 0,
          updated
        });
      }
      const row = grouped.get(security);
      row.quantity += quantity;
      row.updated = updated ?? row.updated;
    }
    return Array.from(grouped.values()).sort((a, b) => String(a.security).localeCompare(String(b.security)));
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
    this.gridApi.sizeColumnsToFit();
  }

}
