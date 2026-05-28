import { CellClickedEvent, ColDef, GetRowIdParams, GridApi, GridReadyEvent } from 'ag-grid-community';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { OrderRecord } from '../model/order.model';
import { PriceTick } from '../model/trade.model';
import { OrderAdminService } from '../service/order-admin.service';
import { TradeFeedService } from '../service/trade-feed.service';
import { PriceSnapshotService } from '../service/price-snapshot.service';

type OrderRow = OrderRecord & {
    marketPrice?: number;
    spreadToStrike?: number;
};

@Component({
    standalone: false,
    selector: 'app-order-admin',
    templateUrl: './order-admin.component.html',
    styleUrls: ['./order-admin.component.scss']
})
export class OrderAdminComponent implements OnInit, OnDestroy {
    rows: OrderRow[] = [];
    gridApi?: GridApi<OrderRow>;
    openOrderCount = 0;
    unfilledOrderCount = 0;
    totalRemainingQuantity = 0;
    actionMessage?: { type: 'success' | 'danger'; text: string };
    private readonly marketPriceByTicker = new Map<string, number>();
    private readonly marketPriceAsOfByTicker = new Map<string, number>();
    private orderUnsubscribeFn?: () => void;
    private priceUnsubscribeFn?: () => void;

    columnDefs: ColDef<OrderRow>[] = [
        { headerName: 'ORDER ID', field: 'orderId' },
        { headerName: 'ACCOUNT', field: 'accountId' },
        { headerName: 'SECURITY', field: 'security' },
        { headerName: 'SIDE', field: 'side' },
        {
            headerName: 'QTY',
            field: 'quantity',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatInteger(value)
        },
        {
            headerName: 'REMAINING',
            field: 'remainingQuantity',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatInteger(value)
        },
        {
            headerName: 'STRIKE',
            field: 'limitPrice',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatCurrency(value)
        },
        {
            headerName: 'MARKET',
            field: 'marketPrice',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatCurrency(value),
            cellStyle: ({ data }) => this.marketStyle(data)
        },
        {
            headerName: 'DELTA',
            field: 'spreadToStrike',
            headerClass: 'ag-right-aligned-header',
            cellClass: 'ag-right-aligned-cell',
            valueFormatter: ({ value }) => this.formatSignedCurrency(value),
            cellStyle: ({ value }) => this.deltaStyle(value)
        },
        { headerName: 'STATUS', field: 'status' },
        { headerName: 'UPDATED', field: 'updatedAt', valueFormatter: ({ value }) => this.toRelativeTime(value) },
        {
            headerName: 'CANCEL',
            colId: 'cancel',
            cellRenderer: () => '<button class="btn btn-outline-danger btn-sm">Cancel</button>'
        },
        {
            headerName: 'FORCE FILL',
            colId: 'forceFill',
            cellRenderer: () => '<button class="btn btn-outline-success btn-sm">Force Fill</button>'
        }
    ];

    constructor(
        private orderAdminService: OrderAdminService,
        private tradeFeed: TradeFeedService,
        private priceSnapshots: PriceSnapshotService
    ) {
        this.getRowId = this.getRowId.bind(this);
    }

    ngOnInit(): void {
        this.reloadOpenOrders();
        this.orderUnsubscribeFn = this.orderAdminService.subscribe('/orders', (order: OrderRecord) => {
            this.applyOrderUpdate(order);
        });
        this.priceUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (tick: PriceTick) => {
            this.applyPriceTick(tick);
        });
    }

    ngOnDestroy(): void {
        this.orderUnsubscribeFn?.();
        this.priceUnsubscribeFn?.();
    }

    onGridReady(params: GridReadyEvent<OrderRow>) {
        this.gridApi = params.api;
        this.gridApi.sizeColumnsToFit();
    }

    onCellClicked(event: CellClickedEvent<OrderRow>): void {
        const orderId = event.data?.orderId;
        if (!orderId) {
            return;
        }
        if (event.colDef.colId === 'cancel') {
            this.orderAdminService.cancelOrder(orderId).subscribe({
                next: (res) => {
                    this.actionMessage = { type: 'success', text: `Canceled ${res.orderId}` };
                },
                error: () => {
                    this.actionMessage = { type: 'danger', text: `Failed to cancel ${orderId}` };
                }
            });
            return;
        }
        if (event.colDef.colId === 'forceFill') {
            this.orderAdminService.forceFillOrder(orderId).subscribe({
                next: (res) => {
                    this.actionMessage = { type: 'success', text: `Force-filled ${res.orderId}` };
                },
                error: () => {
                    this.actionMessage = { type: 'danger', text: `Failed to force-fill ${orderId}` };
                }
            });
        }
    }

    getRowId(params: GetRowIdParams<OrderRow>): string {
        return params?.data?.orderId ?? 'order-unknown';
    }

    private reloadOpenOrders() {
        this.orderAdminService.getOpenOrders().subscribe((orders: OrderRecord[]) => {
            const rows = (orders ?? []).map((order) => this.withLivePricing(order));
            this.rows = rows;
            this.setGridRowData(rows);
            this.updateSummary(rows);
            this.bootstrapSnapshotPrices(rows.map((row) => row.security));
        });
    }

    private applyOrderUpdate(order: OrderRecord): void {
        if (!order?.orderId) {
            return;
        }
        const terminal = this.isTerminalStatus(order.status);
        if (terminal) {
            const filtered = this.rows.filter((row) => row.orderId !== order.orderId);
            if (filtered.length === this.rows.length) {
                return;
            }
            this.rows = filtered;
            this.setGridRowData(filtered);
            this.updateSummary(filtered);
            return;
        }
        const updatedRow = this.withLivePricing(order);
        const existingIndex = this.rows.findIndex((row) => row.orderId === order.orderId);
        const nextRows = [...this.rows];
        if (existingIndex >= 0) {
            nextRows[existingIndex] = updatedRow;
        } else {
            nextRows.unshift(updatedRow);
        }
        nextRows.sort((a, b) => this.toEpochMs(b.updatedAt) - this.toEpochMs(a.updatedAt));
        this.rows = nextRows;
        this.setGridRowData(nextRows);
        this.updateSummary(nextRows);
        this.bootstrapSnapshotPrices([updatedRow.security]);
    }

    private applyPriceTick(tick: PriceTick) {
        if (!tick?.ticker || tick.price == null) {
            return;
        }
        if (!this.applyMarketPriceUpdate(tick.ticker, tick.price, tick.asOf ?? null)) {
            return;
        }
        this.refreshRowsForTicker(tick.ticker);
    }

    private bootstrapSnapshotPrices(tickers: string[]): void {
        this.priceSnapshots.getPrices(tickers).subscribe((snapshots) => {
            const changedTickers = new Set<string>();
            for (const snapshot of snapshots || []) {
                if (!snapshot || !snapshot.ticker || snapshot.price == null) {
                    continue;
                }
                if (this.applyMarketPriceUpdate(snapshot.ticker, snapshot.price, snapshot.asOf ?? null)) {
                    changedTickers.add(String(snapshot.ticker || '').trim().toUpperCase());
                }
            }
            if (changedTickers.size === 0) {
                return;
            }
            for (const ticker of changedTickers) {
                this.refreshRowsForTicker(ticker);
            }
        });
    }

    private applyMarketPriceUpdate(ticker: string, price: number, asOf: string | null): boolean {
        const normalizedTicker = String(ticker || '').trim().toUpperCase();
        const numericPrice = Number(price);
        if (!normalizedTicker || !Number.isFinite(numericPrice)) {
            return false;
        }

        const nextEpoch = this.toPriceEpoch(asOf);
        const currentEpoch = this.marketPriceAsOfByTicker.get(normalizedTicker);
        if (nextEpoch != null) {
            if (currentEpoch != null && nextEpoch < currentEpoch) {
                return false;
            }
            this.marketPriceAsOfByTicker.set(normalizedTicker, nextEpoch);
        } else if (currentEpoch != null) {
            return false;
        }

        this.marketPriceByTicker.set(normalizedTicker, numericPrice);
        return true;
    }

    private refreshRowsForTicker(ticker: string): void {
        if (this.rows.length === 0) {
            return;
        }
        const normalizedTicker = String(ticker || '').trim().toUpperCase();
        let changed = false;
        const updated = this.rows.map((row) => {
            if (String(row.security || '').trim().toUpperCase() !== normalizedTicker) {
                return row;
            }
            changed = true;
            return this.withLivePricing(row);
        });
        if (!changed) {
            return;
        }
        this.rows = updated;
        this.setGridRowData(updated);
    }

    private withLivePricing(order: OrderRecord): OrderRow {
        const normalizedTicker = String(order.security || '').trim().toUpperCase();
        const limitPrice = Number(order.limitPrice ?? 0);
        const marketPrice = this.marketPriceByTicker.get(normalizedTicker);
        const spreadToStrike = marketPrice == null ? undefined : Number(marketPrice) - limitPrice;
        return Object.assign({}, order, {
            security: normalizedTicker,
            limitPrice,
            marketPrice: marketPrice == null ? undefined : Number(marketPrice),
            spreadToStrike
        });
    }

    private updateSummary(rows: OrderRow[]) {
        this.openOrderCount = rows.length;
        this.unfilledOrderCount = rows.filter((row) => Number(row.remainingQuantity ?? 0) > 0).length;
        this.totalRemainingQuantity = rows.reduce((sum, row) => sum + Number(row.remainingQuantity ?? 0), 0);
    }

    private isTerminalStatus(status: string | undefined): boolean {
        return status === 'FILLED' || status === 'CANCELED' || status === 'REJECTED';
    }

    private toEpochMs(value: string | Date | undefined): number {
        if (!value) {
            return 0;
        }
        const ts = new Date(value).getTime();
        return Number.isFinite(ts) ? ts : 0;
    }

    private toPriceEpoch(asOf: string | null | undefined): number | null {
        if (!asOf) {
            return null;
        }
        const ts = new Date(asOf).getTime();
        return Number.isFinite(ts) ? ts : null;
    }

    private setGridRowData(rows: OrderRow[]) {
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

    private marketStyle(data?: OrderRow): any {
        if (!data || data.marketPrice == null) {
            return {};
        }
        const market = Number(data.marketPrice);
        const strike = Number(data.limitPrice);
        if (!Number.isFinite(market) || !Number.isFinite(strike)) {
            return {};
        }
        const favorable = data.side === 'Buy' ? market <= strike : market >= strike;
        return { color: favorable ? '#14532d' : '#991b1b', fontWeight: 700 };
    }

    private deltaStyle(value: any): any {
        const numeric = Number(value);
        if (!Number.isFinite(numeric) || numeric === 0) {
            return {};
        }
        return { color: numeric >= 0 ? '#14532d' : '#991b1b', fontWeight: 700 };
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

    private formatSignedCurrency(value: any): string {
        if (value == null || value === '') {
            return '-';
        }
        const numeric = Number(value);
        if (!Number.isFinite(numeric)) {
            return '-';
        }
        const abs = new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 3,
            maximumFractionDigits: 3
        }).format(Math.abs(numeric));
        return numeric >= 0 ? `+${abs}` : `-${abs}`;
    }

    private formatInteger(value: any): string {
        if (value == null || value === '') {
            return '-';
        }
        const numeric = Number(value);
        if (!Number.isFinite(numeric)) {
            return '-';
        }
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(numeric);
    }

    private toRelativeTime(value: string | Date | undefined): string {
        if (!value) {
            return '-';
        }
        const ts = new Date(value);
        if (Number.isNaN(ts.getTime())) {
            return '-';
        }
        const now = new Date();
        const elapsedMs = now.getTime() - ts.getTime();
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
}
