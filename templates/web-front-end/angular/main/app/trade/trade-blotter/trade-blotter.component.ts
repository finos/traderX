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
    // Settlement ledger persistence: entries are only written AFTER a real
    // StartPayment dispatch (and deleted again if that dispatch failed), so
    // this map holds real history, never fabricated status. Persisting it to
    // localStorage keeps the SETTLE/SETTLING/SETTLED cell truth stable across
    // a window refresh — previously every reload reset the ACTION column to a
    // fresh SETTLE button on rows that had already settled, a trap that made
    // the app look non-persistent.
    private static readonly SETTLEMENT_LEDGER_KEY = 'traderx_settlement_ledger_v1';
    private readonly interopSubscription: Subscription;
    private receiverAvailabilitySubscription?: Subscription;
    private settlementSubscription?: Subscription;
    private snapshotSubscription?: Subscription;
    private snapshotPollTimer?: ReturnType<typeof setInterval>;
    // Durable-truth timers (see reconcileFromRegistry / checkOnChainSettlement).
    private registryPollTimer?: ReturnType<typeof setInterval>;
    private chainPollTimer?: ReturnType<typeof setInterval>;
    private registryPollCycle = 0;
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
            enableCellChangeFlash: true,
            // Once a row's settlement is known, this column shows the UETR
            // (pacs.008 ↔ pacs.002 correlation ID) instead of the adapter's
            // trade-lifecycle text; before any dispatch it stays the raw
            // trade state. The status badge stays in the ACTION column.
            cellRenderer: (params: any) => this.settlementStateCellHtml(params?.data)
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
        this.restoreSettlementLedger();
        // Durable-truth loops: reconcile against the adapter registry (3s) and
        // run the Solana memo watcher (2.5s) so settled state survives a
        // refresh, a SECOND browser, and a mid-flight page that missed the
        // desk's live status broadcast.
        this.reconcileFromRegistry();
        this.registryPollTimer = setInterval(() => this.reconcileFromRegistry(), 3000);
        this.chainPollTimer = setInterval(() => this.checkOnChainSettlement(), 2500);
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
        // Kick off the desktop-agent session up front: the SETTLE column is
        // gated on the StartPayment availability probe, which only runs once
        // the FDC3 interop service has resolved an agent. Without this, the
        // blotter shows no action column until some other code path inits the
        // service (i.e. never on the plain blotter view).
        this.interop.initialize().catch((error) => {
            console.warn('[settlement] FDC3 interop init failed on blotter mount', error);
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
        this.persistSettlementLedger();
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
            this.persistSettlementLedger();
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
            return '<span class="badge bg-warning text-dark font-monospace" style="font-size:10px;">SETTLING…</span>' + this.uetrLine(state.uetr);
        }
        if (state?.status === 'Acsc') {
            return '<span class="badge bg-success font-monospace" style="font-size:10px;">SETTLED</span>' + this.uetrLine(state.uetr);
        }
        if (state?.status === 'Rjct') {
            return '<span class="badge bg-danger font-monospace" style="font-size:10px;">REJECTED</span>' + this.uetrLine(state.uetr);
        }
        return '<button class="btn btn-sm btn-outline-success font-monospace py-0 px-2" style="font-size:10px;">SETTLE (BANKERX)</button>';
    }

    private settlementStateCellHtml(trade?: Trade): string {
        if (!trade) return '';
        const state = this.settlementByRow.get(this.rowKeyFor(trade));
        // Operator directive (2026-10-01): the STATE column must not keep
        // saying the adapter's trade lifecycle ("Pending") after a settlement
        // — once a row's settlement is known, the STATE column shows the
        // UETR (the pacs.008 ↔ pacs.002 correlation ID) instead. The badge
        // stays where it always was, in ACTION.
        if (state) {
            return this.uetrLine(state.uetr);
        }
        return trade.state ?? '';
    }

    // The UETR is the pacs.008 ↔ pacs.002 correlation ID — showing it in the
    // state column (full value on hover) lets the row be traced into the desk
    // receipt modal and the explorer without opening anything.
    private uetrLine(uetr: string): string {
        if (!uetr) return '';
        const short = uetr.length > 14 ? uetr.slice(0, 8) + '…' + uetr.slice(-4) : uetr;
        return `<div class="text-muted font-monospace" title="${uetr}" style="font-size:9px;">${short}</div>`;
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
        // ISO 20022 lifecycle ordering: Pndg → (Acsc | Rjct). pacs.002 terminal
        // statuses are one-way — a late or re-relayed non-terminal (or lower)
        // status on the same UETR does NOT move the row backwards. Today no
        // estate path emits Pndg post-dispatch, but a future mid-flight status
        // (or a stale replay) must never flip a settled row back to SETTLING.
        const RANK: { [s: string]: number } = { Pndg: 0, Acsc: 1, Rjct: 1 };
        for (const [rowKey, state] of this.settlementByRow.entries()) {
            if (state.uetr !== event.uetr) {
                continue;
            }
            const incoming = (RANK[event.status] ?? -1);
            if (incoming < 0 || incoming < (RANK[state.status] ?? 0)) {
                console.info('[settlement] ignored non-forward status report', { uetr: event.uetr, from: state.status, to: event.status });
                return;
            }
            state.status = event.status as 'Acsc' | 'Rjct' | 'Pndg';
            this.persistSettlementLedger();
            this.refreshSettlementCells();
            return;
        }
        console.info('[settlement] status report for unknown row (logged, not applied)', event);
    }

    // Ledger round-trip: localStorage holds { rowId -> { uetr, status } } with
    // real dispatched facts only. Restore happens in the constructor so the
    // map is already populated when the first trade snapshot renders; a
    // corrupt/foreign payload is discarded wholesale rather than half-loaded.
    private restoreSettlementLedger(): void {
        if (typeof localStorage === 'undefined') {
            return;
        }
        try {
            const raw = localStorage.getItem(TradeBlotterComponent.SETTLEMENT_LEDGER_KEY);
            if (!raw) {
                return;
            }
            const parsed = JSON.parse(raw);
            if (!parsed || typeof parsed !== 'object') {
                return;
            }
            for (const [rowKey, entry] of Object.entries(parsed)) {
                const uetr = (entry as any)?.uetr;
                const status = (entry as any)?.status;
                if (typeof rowKey === 'string' && rowKey && typeof uetr === 'string' && uetr
                    && ['Acsc', 'Rjct', 'Pndg'].includes(status)) {
                    this.settlementByRow.set(rowKey, { uetr, status });
                }
            }
        } catch (error) {
            console.warn('[settlement] settlement ledger restore skipped', error);
        }
    }

    private persistSettlementLedger(): void {
        if (typeof localStorage === 'undefined') {
            return;
        }
        try {
            const ledger: { [rowId: string]: { uetr: string; status: 'Acsc' | 'Rjct' | 'Pndg' } } = {};
            for (const [rowKey, entry] of this.settlementByRow.entries()) {
                ledger[rowKey] = { uetr: entry.uetr, status: entry.status };
            }
            localStorage.setItem(TradeBlotterComponent.SETTLEMENT_LEDGER_KEY, JSON.stringify(ledger));
            // Publish to the adapter's durable registry as well: localStorage is
            // per-browser, so a set of settled rows known only here would be
            // invisible to a second browser (fresh SETTLE buttons / rows stuck on
            // SETTLING). Fire-and-forget — the reconcile tick repairs any missed
            // publish.
            this.publishSettlements();
        } catch (error) {
            console.warn('[settlement] settlement ledger persist failed', error);
        }
    }

    // ── Durable settlement truth (adapter registry + Solana memo watcher) ──
    // localStorage is PER-BROWSER, so a second browser showed fresh SETTLE
    // buttons / rows stuck on SETTLING… for trades settled elsewhere. The
    // adapter (:8415 /trade-service/trade/trades/settlements) now owns the
    // durable ledger keyed by UETR: this blotter publishes every transition
    // it observes and reconciles from it on load and on each snapshot tick.
    // Adoption is guarded — an entry is only applied to a row whose identity
    // matches (its own UETR, or a fingerprint-matched tradeId), so a registry
    // entry can never stamp SETTLED onto an unrelated row.
    private publishSettlements(): void {
        if (!this.trades.length) {
            return;
        }
        const entries: any[] = [];
        for (const [rowKey, state] of this.settlementByRow.entries()) {
            const trade = this.trades.find(t => this.rowKeyFor(t) === rowKey);
            const fp = trade ? this.fingerprintOf(trade) : null;
            entries.push(Object.assign({
                tradeId: rowKey.startsWith('Trade-') ? rowKey.slice('Trade-'.length) : rowKey,
                uetr: state.uetr,
                status: state.status
            }, fp ?? {}));
        }
        if (!entries.length) {
            return;
        }
        try {
            this.tradeService.postSettlements(entries).subscribe(
                () => undefined,
                (error: unknown) => console.warn('[settlement] registry publish failed', error)
            );
        } catch (error) {
            console.warn('[settlement] registry publish failed', error);
        }
    }

    // Fingerprint the dispatching browser recorded for the trade: a registry
    // entry is adoptable by a row only when every field matches, so the same
    // tradeId regenerated after an adapter restart (which wipes the in-memory
    // TRADES list) can never inherit an old settlement.
    private fingerprintOf(trade: Trade): any {
        if (!trade?.id) {
            return null;
        }
        return {
            security: trade.security ?? '',
            quantity: Number(trade.quantity ?? 0),
            side: trade.side ?? '',
            created: String((trade as any).created ?? '')
        };
    }

    private matchesFingerprint(trade: Trade, entry: any): boolean {
        // An entry without a complete fingerprint (older publisher) must NOT
        // be adoptable by fingerprint — block rather than risk a wrong-row
        // SETTLED stamp.
        if (!entry || typeof entry !== 'object') {
            return false;
        }
        return entry.security === (trade.security ?? '')
            && Number(entry.quantity) === Number(trade.quantity ?? 0)
            && entry.side === (trade.side ?? '')
            && String(entry.created ?? '') === String((trade as any).created ?? '');
    }

    private reconcileFromRegistry(): void {
        this.tradeService.getSettlements().subscribe((map: { [uetr: string]: any }) => {
            if (!map || typeof map !== 'object') {
                return;
            }
            // Same ISO 20022 ordering guard as applySettlementStatus: pacs.002
            // terminal statuses are one-way.
            const RANK: { [s: string]: number } = { Pndg: 0, Acsc: 1, Rjct: 1 };
            let changed = false;
            for (const entry of Object.values(map) as any[]) {
                if (!entry?.uetr || !(entry.status in RANK)) {
                    continue;
                }
                // Path 1: this browser already tracks a settlement for the
                // SAME UETR (own dispatch, or own ledger) — adopt directly.
                let adoptRowKey: string | null = null;
                for (const [rowKey, state] of this.settlementByRow.entries()) {
                    if (state.uetr === entry.uetr) {
                        adoptRowKey = rowKey;
                        break;
                    }
                }
                // Path 2: second browser — the row was dispatched elsewhere,
                // so this browser holds no UETR for it. Adopt the registry
                // entry's trade identity, but only when a matching trade row
                // exists here AND its fingerprint matches: the adapter's
                // in-memory TRADES list is wiped on restart, and a new trade
                // that recycled an old id must never inherit an old settlement.
                const rowKey = entry.tradeId ? `Trade-${entry.tradeId}` : null;
                if (!adoptRowKey && rowKey && !this.settlementByRow.has(rowKey)) {
                    const trade = this.trades.find(t => this.rowKeyFor(t) === rowKey);
                    if (trade && this.matchesFingerprint(trade, entry)) {
                        adoptRowKey = rowKey;
                    }
                }
                if (!adoptRowKey) {
                    continue;
                }
                const state = this.settlementByRow.get(adoptRowKey);
                if (!state) {
                    this.settlementByRow.set(adoptRowKey, {
                        uetr: entry.uetr,
                        status: entry.status as 'Acsc' | 'Rjct' | 'Pndg'
                    });
                    changed = true;
                    continue;
                }
                const incoming = RANK[entry.status] ?? -1;
                if (incoming < (RANK[state.status] ?? 0)) {
                    continue;
                }
                if (state.status !== entry.status) {
                    state.status = entry.status as 'Acsc' | 'Rjct' | 'Pndg';
                    if (entry.txSignature) {
                        (state as any).txSignature = entry.txSignature;
                    }
                    changed = true;
                }
            }
            if (changed) {
                this.persistSettlementLedger();
                this.refreshSettlementCells();
            }
        }, (error: unknown) => {
            // Registry unreachable (first boot, adapter restart) — next tick retries.
            if (this.registryPollCycle % 20 === 0) {
                console.warn('[settlement] registry reconcile unavailable', error);
            }
            this.registryPollCycle++;
        });
    }

    // Solana devnet memo watcher — ported from the root blotter's
    // checkOnChainSettlement: the desk settles ONLY after its desk-side WOTS+
    // re-derivation passes (a failed attestation honest-rejects and creates
    // no settlement), so an on-chain settlement memo containing a row's UETR
    // IS authoritative Acsc for it even when every page that observed the
    // settle is closed or sits in another browser. Resolved rows are
    // published to the registry so every other browser reconciles within
    // one tick.
    private static readonly SOLANA_DEVNET_RPC = 'https://api.devnet.solana.com';
    private static readonly CREDITOR_TOKEN_ACCOUNT = 'BnuCTFWFLLXnSPv2Frs42royiTAYG87WP7p1zRLB4ksG';
    private chainChecking = false;

    private checkOnChainSettlement(): void {
        if (this.chainChecking || typeof fetch === 'undefined') {
            return;
        }
        const pending = [...this.settlementByRow.entries()].filter(([, s]) => s.status === 'Pndg');
        if (!pending.length) {
            return;
        }
        this.chainChecking = true;
        const settledNow: any[] = [];
        const http$ = fetch(TradeBlotterComponent.SOLANA_DEVNET_RPC, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                jsonrpc: '2.0',
                id: 1,
                method: 'getSignaturesForAddress',
                params: [TradeBlotterComponent.CREDITOR_TOKEN_ACCOUNT, { limit: 10 }]
            })
        }).then(res => res.json()).then((data: any) => {
            for (const sig of (data?.result ?? [])) {
                if (!sig?.memo) {
                    continue;
                }
                for (const [rowKey, state] of pending) {
                    if (state.status !== 'Pndg' || !sig.memo.includes(state.uetr)) {
                        continue;
                    }
                    state.status = 'Acsc';
                    (state as any).txSignature = sig.signature;
                    settledNow.push({
                        tradeId: rowKey.slice('Trade-'.length),
                        uetr: state.uetr,
                        status: 'Acsc',
                        txSignature: sig.signature
                    });
                    console.log('[settlement] on-chain SETTLED (memo watcher)', {
                        rowKey, uetr: state.uetr, tx: String(sig.signature).slice(0, 16)
                    });
                }
            }
        }).catch(() => {
            // Non-blocking network check — devnet flake, next tick retries.
        }).finally(() => {
            this.chainChecking = false;
            if (settledNow.length) {
                this.persistSettlementLedger();
                this.refreshSettlementCells();
                try {
                    this.tradeService.postSettlements(settledNow).subscribe(
                        () => undefined, () => undefined
                    );
                } catch (error) {
                    console.warn('[settlement] registry publish failed', error);
                }
            }
        });
        http$.catch(() => undefined); // fetch itself must never throw out of a timer
    }

    private refreshSettlementCells(): void {
        this.trades = [...this.trades];
        this.gridApi?.setGridOption('rowData', this.trades);
        // Row data is immutable to ag-Grid under getRowId, so a rowData reset
        // alone does not re-run cell renderers — and a plain refreshCells()
        // only re-renders cells whose VALUE changed. The ACTION badge would
        // repaint (its valueGetter returns the new status) but the STATE
        // column's field value never changes (e.g. "Pending" stays
        // "Pending"), so its renderer was skipped and the UETR only appeared
        // after a reload. force:true re-runs every renderer so the STATE
        // column's UETR paints live, with the settlementByRow map already
        // updated.
        this.gridApi?.refreshCells({ force: true });
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
        this.stopSnapshotPolling();
        if (this.registryPollTimer) {
            clearInterval(this.registryPollTimer);
            this.registryPollTimer = undefined;
        }
        if (this.chainPollTimer) {
            clearInterval(this.chainPollTimer);
            this.chainPollTimer = undefined;
        }
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
            this.startSnapshotPolling(() => this.tradeService.getAllTrades());
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
        this.startSnapshotPolling(() => this.tradeService.getTrades(accountId));
    }

    private clearSubscriptions() {
        for (const unSub of this.socketUnSubscribeFns) {
            unSub?.();
        }
        this.socketUnSubscribeFns = [];
        this.stopSnapshotPolling();
    }

    // Live-refresh for raised trade tickets: the trade-feed Socket.IO channel
    // served by the estate Synaptic adapter is a handshake mock (no live
    // event stream), so a newly created ticket previously appeared only after
    // a full window refresh re-pulled the REST snapshot. Poll the real
    // snapshot endpoint as the change channel and merge in only NEW trades —
    // existing rows keep their object identity so ag-Grid's getRowId /
    // immutable-rowData contract stays intact, and the settlement-ledger
    // badges render on the fresh rows right away.
    private startSnapshotPolling(fetchSnapshot: () => Observable<Trade[]>): void {
        this.snapshotPollTimer = setInterval(() => {
            fetchSnapshot().subscribe((trades: Trade[]) => {
                this.mergeSnapshot(trades ?? []);
            }, () => {
                // Poll cycle failed (adapter restart etc.) — next tick retries.
            });
        }, 3000);
    }

    private stopSnapshotPolling(): void {
        if (this.snapshotPollTimer) {
            clearInterval(this.snapshotPollTimer);
            this.snapshotPollTimer = undefined;
        }
    }

    private mergeSnapshot(fetched: Trade[]): void {
        let changed = false;
        for (const trade of fetched) {
            if (trade?.id == null) {
                continue;
            }
            const exists = this.trades.some(existing => existing.id === trade.id);
            if (!exists) {
                this.update(this.withAccountDisplay(trade));
                changed = true;
            }
        }
        if (changed) {
            this.refreshSettlementCells();
        }
        // First trade rows just landed — pull the registry now instead of
        // waiting up to a whole 3s tick for fresh-second-browser rows to
        // adopt their settled status.
        this.reconcileFromRegistry();
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
