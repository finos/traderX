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
            headerName: 'QUANTITY',
            field: 'quantity'
        },
        {
            headerName: 'SIDE',
            field: 'side'
        },
        {
            headerName: 'STATE',
            field: 'state',
            enableCellChangeFlash: true
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
                update: [Object.assign(row.data, { state: tradeWithDisplay.state, accountDisplayName: tradeWithDisplay.accountDisplayName })]
            };
        } else {
            tradeData = {
                add: [{
                    accountid: tradeWithDisplay.accountid,
                    accountDisplayName: tradeWithDisplay.accountDisplayName,
                    created: tradeWithDisplay.created,
                    id: tradeWithDisplay.id,
                    quantity: tradeWithDisplay.quantity,
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
        const accountId = Number((data as any).accountid ?? 0);
        const accountDisplayName = this.accountNameById[accountId] ?? `#${accountId}`;
        return Object.assign({}, data, { accountid: accountId, accountDisplayName });
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

    private toRowId(id: string | number | undefined): string {
        return `Trade-${id ?? 'unknown'}`;
    }
}
