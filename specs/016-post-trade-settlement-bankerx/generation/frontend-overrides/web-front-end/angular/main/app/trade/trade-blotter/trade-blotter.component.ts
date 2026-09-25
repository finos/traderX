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
    paymentReceiverAvailable = false;
    private readonly settlementByRow = new Map<string, { uetr: string; status: 'Acsc' | 'Rjct' | 'Pndg' }>();
    private readonly interopSubscription: Subscription;
    private receiverAvailabilitySubscription?: Subscription;
    private settlementSubscription?: Subscription;
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

    private readonly settleColumn: ColDef = {
        headerName: 'ACTION',
        field: 'action',
        valueGetter: (params: any) => this.settlementActionLabel(params?.data),
        cellRenderer: (params: any) => this.settlementCellHtml(params?.data),
        onCellClicked: (params: any) => this.onSettleCellClicked(params.data)
    };

    constructor(private tradeFeed: TradeFeedService, private tradeService: PositionService, private interop: Fdc3InteropService) {
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
        // The SETTLE action column only renders when a workspace participant
        // declares support for the StartPayment intent (e.g. the local mock
        // receiver or the BankerX reference adapter). Base TraderX with no
        // post-trade participant shows the pristine 014 blotter.
        this.receiverAvailabilitySubscription = interop.paymentReceiverAvailable$.subscribe(available => {
            if (this.paymentReceiverAvailable !== available) {
                this.paymentReceiverAvailable = available;
                this.configureColumns();
            }
        });
        // Correlate pacs.002-style status reports back to dispatched rows by UETR.
        this.settlementSubscription = interop.settlementStatus$.subscribe(event => {
            this.applySettlementStatus(event);
        });
    }

    async settleTrade(trade: Trade): Promise<void> {
        if (!trade) return;
        const rowId = this.rowKeyFor(trade);
        const existing = this.settlementByRow.get(rowId);
        if (existing && (existing.status === 'Pndg' || existing.status === 'Acsc')) {
            console.warn('[settlement] duplicate dispatch suppressed', { rowId, ...existing });
            this.interop.statusMessage$.next(
                existing.status === 'Pndg'
                    ? 'FDC3: settlement already in flight for this trade'
                    : 'FDC3: trade already settled'
            );
            return;
        }
        const pair = `${trade.security || 'USD'}/KES`;
        const uetr = this.newUetr();
        this.settlementByRow.set(rowId, { uetr, status: 'Pndg' });
        this.refreshSettlementCells();
        const dispatched = await this.interop.raiseStartPayment({
            amount: (trade.price || 1) * (trade.quantity || 1000),
            currency: trade.security || 'USD',
            pair,
            rate: trade.price || 1.0,
            debtor: {
                name: 'TraderX Institutional Execution Desk',
                account: this.account?.name || 'traderx-desk-01'
            },
            creditor: {
                name: 'BankerX Institutional Liquidity Desk',
                account: 'bankerx-settler-01'
            },
            uetr
        });
        if (!dispatched) {
            console.error('[settlement] StartPayment dispatch failed; reverting row', { rowId, uetr });
            this.settlementByRow.delete(rowId);
            this.refreshSettlementCells();
        }
    }

    private onSettleCellClicked(trade: Trade): void {
        if (!trade) return;
        const existing = this.settlementByRow.get(this.rowKeyFor(trade));
        if (existing && (existing.status === 'Pndg' || existing.status === 'Acsc')) {
            return;
        }
        this.settleTrade(trade);
    }

    private settlementActionLabel(trade?: Trade): string {
        if (!trade) return '';
        return this.settlementByRow.get(this.rowKeyFor(trade))?.status ?? '';
    }

    private settlementCellHtml(trade?: Trade): string {
        if (!trade) return '';
        const state = this.settlementByRow.get(this.rowKeyFor(trade));
        if (state?.status === 'Pndg') {
            return '<span class="badge bg-warning text-dark font-monospace" style="font-size:10px;">SETTLING…</span>';
        }
        if (state?.status === 'Acsc') {
            return '<span class="badge bg-success font-monospace" style="font-size:10px;">SETTLED</span>';
        }
        if (state?.status === 'Rjct') {
            return '<span class="badge bg-danger font-monospace" style="font-size:10px;">REJECTED</span>';
        }
        return '<button class="btn btn-sm btn-outline-success font-monospace py-0 px-2" style="font-size:10px;">SETTLE (BANKERX)</button>';
    }

    private rowKeyFor(trade: Trade): string {
        return trade?.id ? `Trade-${trade.id}` : 'Trade-unknown';
    }

    private newUetr(): string {
        return typeof crypto !== 'undefined' && crypto.randomUUID
            ? crypto.randomUUID()
            : `UETR-${Date.now()}`;
    }

    private applySettlementStatus(event: { uetr: string; status: string }): void {
        for (const [rowKey, state] of this.settlementByRow.entries()) {
            if (state.uetr !== event.uetr) {
                continue;
            }
            state.status = event.status as 'Acsc' | 'Rjct' | 'Pndg';
            this.refreshSettlementCells();
            return;
        }
        console.info('[settlement] status report for unknown row (logged, not applied)', event);
    }

    private refreshSettlementCells(): void {
        this.trades = [...this.trades];
        this.gridApi?.setGridOption('rowData', this.trades);
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
        this.receiverAvailabilitySubscription?.unsubscribe();
        this.settlementSubscription?.unsubscribe();
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
        const settleColumns: ColDef[] = this.paymentReceiverAvailable ? [this.settleColumn] : [];
        this.columnDefs = [...allAccountsColumns, ...this.baseColumns, ...settleColumns];
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
