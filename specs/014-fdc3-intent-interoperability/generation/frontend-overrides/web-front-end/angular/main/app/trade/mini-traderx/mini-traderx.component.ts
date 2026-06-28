import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { Account } from '../../model/account.model';
import { PortfolioSummary, PriceTick } from '../../model/trade.model';
import { AccountService } from '../../service/account.service';
import { Fdc3AccountEvent, Fdc3InteropService, Fdc3InboundEvent } from '../../service/fdc3-interop.service';
import { PriceSnapshotService } from '../../service/price-snapshot.service';
import { TradeFeedService } from '../../service/trade-feed.service';

@Component({
    standalone: false,
    selector: 'app-mini-traderx',
    templateUrl: './mini-traderx.component.html',
    styleUrls: ['./mini-traderx.component.scss']
})
export class MiniTraderxComponent implements OnInit, OnDestroy {
    private readonly allAccountsOption: Account = {
        id: 0,
        displayName: 'All Accounts'
    };

    accounts: Account[] = [];
    realAccounts: Account[] = [];
    accountIds: number[] = [];
    accountModel?: Account;
    selectedTicker = '';
    currentPrice?: PriceTick | null;
    status = 'FDC3: connecting...';
    summary: PortfolioSummary = {
        totalMarketValue: 0,
        totalCostBasis: 0,
        totalPnl: 0
    };

    private readonly subscriptions = new Subscription();
    private priceStreamUnsubscribeFn?: Function;
    private pendingAccountId?: number;

    constructor(
        private accountService: AccountService,
        private fdc3Interop: Fdc3InteropService,
        private priceSnapshots: PriceSnapshotService,
        private tradeFeed: TradeFeedService
    ) {}

    ngOnInit(): void {
        this.fdc3Interop.initialize().catch((error) => {
            console.warn('[fdc3] Mini TraderX failed to initialize FDC3', error);
        });

        this.subscriptions.add(
            this.fdc3Interop.statusMessage$.subscribe((status) => {
                this.status = status;
            })
        );
        this.subscriptions.add(
            this.fdc3Interop.inboundEvents$.subscribe((event) => this.handleInboundInstrument(event))
        );
        this.subscriptions.add(
            this.fdc3Interop.accountEvents$.subscribe((event) => this.handleInboundAccount(event))
        );

        this.accountService.getAccounts().subscribe((accounts) => {
            this.realAccounts = accounts ?? [];
            this.accountIds = this.realAccounts.map((account) => account.id);
            this.accounts = [this.allAccountsOption, ...this.realAccounts];
            const pendingAccount = this.pendingAccountId == null
                ? undefined
                : this.accounts.find((account) => Number(account.id) === this.pendingAccountId);
            this.setAccount(pendingAccount ?? this.realAccounts[0] ?? this.allAccountsOption, false);
            this.pendingAccountId = undefined;
        });

        this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (tick: PriceTick) => {
            this.applyPriceTick(tick);
        });
    }

    ngOnDestroy(): void {
        this.priceStreamUnsubscribeFn?.();
        this.subscriptions.unsubscribe();
    }

    onAccountChange(account: Account): void {
        if (!account) {
            return;
        }
        this.setAccount(account, true);
    }

    onSummaryChange(summary: PortfolioSummary): void {
        this.summary = summary;
    }

    onSecuritySelected(security: string): void {
        const normalized = this.normalizeTicker(security);
        if (!normalized) {
            return;
        }
        this.applyTicker(normalized);
        this.fdc3Interop.publishTickerSelection(normalized).catch((error) => {
            console.warn('[fdc3] Mini TraderX failed to broadcast instrument context', error);
        });
    }

    get isAllAccountsSelected(): boolean {
        return (this.accountModel?.id ?? -1) === this.allAccountsOption.id;
    }

    get priceDisplay(): string {
        const price = Number(this.currentPrice?.price);
        return Number.isFinite(price) ? this.formatCurrency(price) : '-';
    }

    private setAccount(account: Account, publishSelection: boolean): void {
        this.accountModel = account;
        this.summary = {
            totalMarketValue: 0,
            totalCostBasis: 0,
            totalPnl: 0
        };
        if (publishSelection) {
            this.fdc3Interop.publishAccountSelection(account).catch((error) => {
                console.warn('[fdc3] Mini TraderX failed to broadcast account context', error);
            });
        }
    }

    private handleInboundInstrument(event: Fdc3InboundEvent): void {
        const normalized = this.normalizeTicker(event?.ticker);
        if (!normalized) {
            return;
        }
        this.applyTicker(normalized);
    }

    private handleInboundAccount(event: Fdc3AccountEvent): void {
        const accountId = Number(event?.accountId);
        if (!Number.isFinite(accountId)) {
            return;
        }
        const account = this.accounts.find((candidate) => Number(candidate.id) === accountId);
        if (!account) {
            this.pendingAccountId = accountId;
            return;
        }
        this.setAccount(account, false);
    }

    private applyTicker(ticker: string): void {
        this.selectedTicker = ticker;
        this.currentPrice = null;
        this.priceSnapshots.getPrice(ticker).subscribe((snapshot) => {
            if (this.normalizeTicker(snapshot?.ticker) === this.selectedTicker) {
                this.currentPrice = snapshot;
            }
        });
    }

    private applyPriceTick(tick: PriceTick): void {
        const ticker = this.normalizeTicker(tick?.ticker);
        if (!ticker || ticker !== this.selectedTicker || tick.price == null) {
            return;
        }
        this.currentPrice = {
            ...tick,
            ticker
        };
    }

    private normalizeTicker(ticker: string | null | undefined): string {
        return String(ticker || '').trim().toUpperCase();
    }

    private formatCurrency(value: number): string {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(value);
    }
}
