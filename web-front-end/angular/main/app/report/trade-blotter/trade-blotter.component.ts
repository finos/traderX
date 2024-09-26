import { ColDef, GridApi, GridReadyEvent } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PriceService } from 'main/app/service/price.service';
import { Observable } from 'rxjs';
import { Trade, TradeInterval } from '../../model/trade.model';

@Component({
    selector: 'app-trade-blotter',
    templateUrl: 'trade-blotter.component.html'
})
export class TradeBlotterComponent implements OnChanges, OnDestroy {
    trades$: Observable<Trade[]>;
    @Input() account?: Account;
    @Input() interval?: TradeInterval;
    trades: Trade[] = [];
    gridApi: GridApi;
    pendingTrades: Trade[] = [];
    isPending = true;
    socketUnSubscribeFn: Function;
    height = '350px';
    width = '100%';
    columnDefs: ColDef[] = [
        {
            headerName: 'SECURITY',
            field: 'security',
	    flex: 1
        },
        {
            headerName: 'QUANTITY',
            field: 'quantity',
	    flex: 1
        },
        {
            headerName: 'SIDE',
            field: 'side',
	    flex: 1
        },
        {
            headerName: 'STATE',
            field: 'state',
	    flex: 1
        },
        {
            headerName: 'UNIT PRICE',
            field: 'price',
	    flex: 1
        }
    ];

    constructor(private priceService: PriceService) { }

    ngOnChanges(change: SimpleChanges) {
      console.log(`Trade blotter change:`, change);
        if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
            this.account = change.account.currentValue;
        }
        if (change.interval?.currentValue && change.interval.currentValue !== change.interval.previousValue) {
          this.interval = change.interval.currentValue;
        }
        const interval = this.interval;
        const accountId = this.account?.id || 52355;
        this.isPending = true;
        this.priceService.getTrades(accountId, interval).subscribe((trades: Trade[]) => {
            this.trades = trades;
            this.processPendingTrades();
        });
    }

    onGridReady(params: GridReadyEvent) {
        console.log('trade blotter is ready...');
        this.gridApi = params.api;
        this.gridApi.sizeColumnsToFit();
    }

    getRowNodeId(data: Trade) {
        return data.id;
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
        const row = this.gridApi.getRowNode(data.id);
        let tradeData;
        if (row) {
            tradeData = {
                update: [Object.assign(row.data, { state: data.state })]
            };
        } else {
            tradeData = {
                add: [{
                    accountid: data.accountid,
                    created: data.created,
                    id: data.id,
                    quantity: data.quantity,
                    security: data.security,
                    side: data.side,
                    updated: data.updated,
                    unitPrice: data.unitPrice
                }],
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
}
