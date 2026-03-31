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
    @Input() allAccountsMode = false;
    @Input() accountIds: number[] = [];
    @Input() accountNameById: { [accountId: number]: string } = {};
    trades: Trade[] = [];
    gridApi: GridApi;
    pendingTrades: Trade[] = [];
    isPending = true;
    socketUnSubscribeFns: Function[] = [];
    columnDefs: ColDef[] = [];
    private readonly baseColumns: ColDef[] = [
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
        const scopeChanged =
            !!change.account ||
            !!change.allAccountsMode ||
            !!change.accountIds ||
            !!change.accountNameById;
        if (scopeChanged) {
            this.configureColumns();
            this.loadScope();
        }
    }

    onGridReady(params: GridReadyEvent) {
        console.log('trade blotter is ready...');
        this.gridApi = params.api;
        this.configureColumns();
        this.gridApi.sizeColumnsToFit();
    }

    getRowId(params: GetRowIdParams<any>):string {
        if (!params?.data?.id) {
            return 'Trade-unknown';
        }
        return  `Trade-${params.data.id}`;
    }

    ngOnDestroy() {
        this.clearSubscriptions();
    }

    private processPendingTrades() {
        this.pendingTrades.forEach((tradeUpdate) => this.update(tradeUpdate));
        this.pendingTrades = [];
        this.isPending = false;
    }

    private update(data: Trade) {
        if (!this.gridApi) {
            this.pendingTrades.push(data);
            return;
        }
        const tradeWithDisplay = this.withAccountDisplay(data);
        const row = this.gridApi.getRowNode(this.toRowId(tradeWithDisplay.id));
        let tradeData;
        if (row) {
            tradeData = {
                update: [Object.assign(row.data, {
                    state: tradeWithDisplay.state,
                    price: tradeWithDisplay.price,
                    updated: tradeWithDisplay.updated,
                    created: tradeWithDisplay.created,
                    accountDisplayName: tradeWithDisplay.accountDisplayName
                })]
            };
        } else {
            tradeData = {
                add: [{
                    accountid: tradeWithDisplay.accountid,
                    accountId: tradeWithDisplay.accountId,
                    accountDisplayName: tradeWithDisplay.accountDisplayName,
                    created: tradeWithDisplay.created,
                    id: tradeWithDisplay.id,
                    quantity: tradeWithDisplay.quantity,
                    price: tradeWithDisplay.price,
                    security: tradeWithDisplay.security,
                    side: tradeWithDisplay.side,
                    state: tradeWithDisplay.state,
                    updated: tradeWithDisplay.updated
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

    private loadScope() {
        this.isPending = true;
        this.clearSubscriptions();

        if (this.allAccountsMode) {
            this.tradeService.getAllTrades().subscribe((trades: Trade[]) => {
                this.trades = (trades ?? []).map((trade) => this.withAccountDisplay(trade));
                this.processPendingTrades();
            }, () => {
                this.isPending = false;
            });
            for (const accountId of this.accountIds) {
                const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/trades`, (data: Trade) => {
                    console.log('Trade blotter feed...', data);
                    this.updateTrades(data);
                });
                this.socketUnSubscribeFns.push(unSub);
            }
            return;
        }

        const accountId = this.account?.id;
        if (!accountId || accountId <= 0) {
            this.trades = [];
            this.pendingTrades = [];
            this.isPending = false;
            return;
        }

        this.tradeService.getTrades(accountId).subscribe((trades: Trade[]) => {
            this.trades = (trades ?? []).map((trade) => this.withAccountDisplay(trade));
            this.processPendingTrades();
        }, () => {
            this.isPending = false;
        });

        const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/trades`, (data: Trade) => {
            console.log('Trade blotter feed...', data);
            this.updateTrades(data);
        });
        this.socketUnSubscribeFns.push(unSub);
    }

    private clearSubscriptions() {
        for (const unSub of this.socketUnSubscribeFns) {
            unSub?.();
        }
        this.socketUnSubscribeFns = [];
    }

    private withAccountDisplay(data: Trade): Trade & { accountDisplayName: string } {
        const accountId = Number((data as any).accountId ?? (data as any).accountid ?? 0);
        const accountDisplayName = this.accountNameById[accountId] ?? `#${accountId}`;
        return Object.assign({}, data, { accountId, accountid: accountId, accountDisplayName });
    }

    private configureColumns() {
        const allAccountsColumns: ColDef[] = this.allAccountsMode ? [{
            headerName: 'ACCOUNT',
            field: 'accountDisplayName'
        }] : [];
        this.columnDefs = [...allAccountsColumns, ...this.baseColumns];
        if (!this.gridApi) {
            return;
        }
        if (typeof (this.gridApi as any).setGridOption === 'function') {
            (this.gridApi as any).setGridOption('columnDefs', this.columnDefs);
        } else if (typeof (this.gridApi as any).setColumnDefs === 'function') {
            (this.gridApi as any).setColumnDefs(this.columnDefs);
        }
        this.gridApi.sizeColumnsToFit();
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
