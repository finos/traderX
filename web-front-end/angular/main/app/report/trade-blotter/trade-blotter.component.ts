import { ColDef, GridApi, GridReadyEvent } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PriceService } from 'main/app/service/price.service';
import { Observable } from 'rxjs';
import { Trade } from '../../model/trade.model';

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
            headerName: 'UNIT PRICE',
            field: 'price'
        }
    ];

    constructor(private priceService: PriceService) { }

    ngOnChanges(change: SimpleChanges) {
        if (change.account?.currentValue && change.account.currentValue !== change.account.previousValue) {
            const accountId = change.account.currentValue.id;
            this.isPending = true;
            this.priceService.getTrades(accountId).subscribe((trades: Trade[]) => {
                this.trades = trades;
                this.processPendingTrades();
            });
        }
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
