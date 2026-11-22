import { Fdc3InteropService } from 'main/app/service/fdc3-interop.service';
import { Observable, Subscription, asapScheduler, filter, observeOn } from 'rxjs';
import { ColDef, GridApi, GridReadyEvent, GetRowIdParams, RowClickedEvent } from 'ag-grid-community';
import { Component, EventEmitter, Input, OnChanges, OnDestroy, Output, SimpleChanges } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { PositionService } from 'main/app/service/position.service';
import { Trade } from '../../model/trade.model';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

@Component({
    standalone: false,
    selector: 'app-trade-blotter',
    templateUrl: 'trade-blotter.component.html'
})
export class TradeBlotterComponent implements OnChanges, OnDestroy {
    trades$: Observable<Trade[]>;
    @Input() account?: Account;
    @Input() allAccountsMode = false;
    @Input() accountIds: number[] = [];
    @Input() accountNameById: { [accountId: number]: string } = {};
    @Input() securityFilter = '';
    filterOnSelectedTicker = false;
    private readonly interopSubscription: Subscription;
    private snapshotSubscription?: Subscription;
    private readonly connectionSubscription: Subscription;

    get effectiveTicker(): string {
        return this.filterOnSelectedTicker ? this.securityFilter.trim().toUpperCase() : '';
    }

    get tickerFilterDescription(): string {
        return this.effectiveTicker ? `Ticker: ${this.effectiveTicker}`
            : this.filterOnSelectedTicker ? 'All tickers — no ticker selected' : 'All tickers';
    }

    setTickerFilter(enabled: boolean): void {
        this.filterOnSelectedTicker = enabled;
        this.applySecurityFilter();
    }

    isExternalFilterPresent = (): boolean => !!this.effectiveTicker;
    doesExternalFilterPass = (node: { data?: { security?: string } }): boolean =>
        !this.effectiveTicker || String(node.data?.security || '').trim().toUpperCase() === this.effectiveTicker;

    @Output() securitySelected = new EventEmitter<string>();
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

    constructor(private tradeFeed: TradeFeedService, private tradeService: PositionService, interop: Fdc3InteropService) {
        this.connectionSubscription = this.tradeFeed.connectionState$.pipe(
            filter(state => state === 'connected'), observeOn(asapScheduler)
        ).subscribe(() => {
            // Let the transport finish its CONNECT/resubscribe handshake first.
            this.loadScope();
        });
        this.interopSubscription = interop.selectedTicker$.subscribe(ticker => {
            this.securityFilter = ticker;
            this.applySecurityFilter();
        });
    }

    ngOnChanges(change: SimpleChanges) {
        const scopeChanged =
            !!change.account ||
            !!change.allAccountsMode ||
            !!change.accountIds ||
            !!change.accountNameById;

        if (change.securityFilter && !scopeChanged) {
            this.applySecurityFilter();
        }
        if (scopeChanged) {
            this.configureColumns();
            this.loadScope();
        }
    }

    onGridReady(params: GridReadyEvent) {
        console.log('trade blotter is ready...');
        this.gridApi = params.api;
        this.configureColumns();
        this.applySecurityFilter();
        this.gridApi.sizeColumnsToFit();
    }

    onRowClicked(event: RowClickedEvent) {
        const security = String((event?.data as any)?.security || '').trim().toUpperCase();
        if (!security) {
            return;
        }
        this.securitySelected.emit(security);
    }

    getRowId(params: GetRowIdParams<any>):string {
        if (!params?.data?.id) {
            return 'Trade-unknown';
        }
        return  `Trade-${params.data.id}`;
    }

    ngOnDestroy() {
        this.interopSubscription.unsubscribe();
        this.connectionSubscription.unsubscribe();
        this.snapshotSubscription?.unsubscribe();
        this.clearSubscriptions();
    }

    private processPendingTrades() {
        this.pendingTrades.forEach((tradeUpdate) => this.update(tradeUpdate));
        this.pendingTrades = [];
        this.isPending = false;
        this.gridApi?.setGridOption('rowData', this.trades);
    }

    private update(data: Trade) {
        const row = this.withAccountDisplay(data);
        const index = this.trades.findIndex(trade => trade.id === row.id);
        this.trades = index < 0 ? [row, ...this.trades]
            : this.trades.map((trade, i) => i === index ? row : trade);
        this.gridApi?.setGridOption('rowData', this.trades);
    }

    private updateTrades(data: Trade) {
        if (this.isPending) {
            this.pendingTrades.push(data);
        } else {
            this.update(data);
        }
    }

    private loadScope() {
        this.snapshotSubscription?.unsubscribe();
        this.trades = [];
        this.gridApi?.setGridOption('rowData', []);
        this.isPending = true;
        this.pendingTrades = [];
        this.clearSubscriptions();

        if (this.allAccountsMode) {
            for (const accountId of this.accountIds) {
                const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/trades`, (data: Trade) => {
                    console.log('Trade blotter feed...', data);
                    this.updateTrades(data);
                });
                this.socketUnSubscribeFns.push(unSub);
            }
            this.snapshotSubscription = this.tradeService.getAllTrades().subscribe((trades: Trade[]) => {
                this.trades = (trades ?? []).map((trade) => this.withAccountDisplay(trade));
                this.processPendingTrades();
            }, () => {
                this.processPendingTrades();
            });
            return;
        }

        const accountId = this.account?.id;
        if (!accountId || accountId <= 0) {
            this.trades = [];
            this.pendingTrades = [];
            this.isPending = false;
            return;
        }

        const unSub = this.tradeFeed.subscribe(`/accounts/${accountId}/trades`, (data: Trade) => {
            console.log('Trade blotter feed...', data);
            this.updateTrades(data);
        });
        this.socketUnSubscribeFns.push(unSub);

        this.snapshotSubscription = this.tradeService.getTrades(accountId).subscribe((trades: Trade[]) => {
            this.trades = (trades ?? []).map((trade) => this.withAccountDisplay(trade));
            this.processPendingTrades();
        }, () => {
            this.processPendingTrades();
        });
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
        this.applySecurityFilter();
        this.gridApi.sizeColumnsToFit();
    }

    private applySecurityFilter() {
        if (!this.gridApi) {
            return;
        }
            this.gridApi.onFilterChanged();
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
