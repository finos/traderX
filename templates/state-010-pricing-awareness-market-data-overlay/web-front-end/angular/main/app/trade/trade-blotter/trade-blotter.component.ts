import { ColDef, GridApi, GridReadyEvent, GetRowIdParams } from 'ag-grid-community';
import { Component, Input, OnChanges, OnDestroy, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PositionService } from 'main/app/service/position.service';
import { Observable } from 'rxjs';
import { Trade } from '../../model/trade.model';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

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
            headerName: 'PRICE',
            field: 'price',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatCurrency(value)
        },
        {
            headerName: 'QUANTITY',
            field: 'quantity',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatInteger(value)
        },
        {
            headerName: 'SIDE',
            field: 'side'
        },
        {
            headerName: 'STATE',
            field: 'state',
            enableCellChangeFlash: true
        },
        {
            headerName: 'EXECUTED',
            field: 'created',
            valueFormatter: ({ value }) => this.toRelativeTime(value)
        }
    ];

    constructor(private tradeFeed: TradeFeedService, private tradeService: PositionService) { }

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

    getRowId(params: GetRowIdParams<any>):string {
        if (!params?.data?.id) {
            return 'Trade-unknown';
        }
        return  `Trade-${params.data.id}`;
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
        const row = this.gridApi.getRowNode(this.toRowId(data.id));
        let tradeData;
        if (row) {
            tradeData = {
                update: [Object.assign(row.data, { state: data.state, price: data.price, updated: data.updated, created: data.created })]
            };
        } else {
            tradeData = {
                add: [{
                    accountid: data.accountid,
                    accountId: data.accountId,
                    created: data.created,
                    id: data.id,
                    quantity: data.quantity,
                    price: data.price,
                    security: data.security,
                    side: data.side,
                    state: data.state,
                    updated: data.updated
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

    private toRowId(id: string): string {
        return `Trade-${id}`;
    }

    private toRelativeTime(value: Date | string | undefined): string {
        if (!value) {
            return '-';
        }
        const timestamp = new Date(value);
        if (Number.isNaN(timestamp.getTime())) {
            return '-';
        }
        const now = new Date();
        if (now.toDateString() !== timestamp.toDateString()) {
            return timestamp.toLocaleString();
        }
        const elapsedMs = now.getTime() - timestamp.getTime();
        const elapsedMins = Math.max(0, Math.floor(elapsedMs / 60000));
        if (elapsedMins < 1) {
            return 'just now';
        }
        if (elapsedMins < 60) {
            return `${elapsedMins} min ago`;
        }
        const hours = Math.floor(elapsedMins / 60);
        return `${hours} hr ago`;
    }

    private formatCurrency(value: any): string {
        if (value == null || value === '') {
            return '-';
        }
        const numeric = Number(value);
        if (!Number.isFinite(numeric)) {
            return '-';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 3,
            maximumFractionDigits: 3
        }).format(numeric);
    }

    private formatInteger(value: any): string {
        if (value == null || value === '') {
            return '-';
        }
        const numeric = Number(value);
        if (!Number.isFinite(numeric)) {
            return '-';
        }
        return new Intl.NumberFormat('en-US', {
            maximumFractionDigits: 0
        }).format(numeric);
    }
}
