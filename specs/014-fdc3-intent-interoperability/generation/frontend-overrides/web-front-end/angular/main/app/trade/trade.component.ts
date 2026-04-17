import { Component, OnDestroy, OnInit, TemplateRef, ViewChild } from '@angular/core';
import { Subject, Subscription } from 'rxjs';
import { PortfolioSummary, PriceTick, TradeTicket, Position } from '../model/trade.model';
import { Account } from '../model/account.model';
import { AccountService } from '../service/account.service';
import { Stock } from '../model/symbol.model';
import { SymbolService } from '../service/symbols.service';
import { BsModalService, BsModalRef } from 'ngx-bootstrap/modal';
import { PositionService } from '../service/position.service';
import { TradeFeedService } from '../service/trade-feed.service';
import { OrderAdminService } from '../service/order-admin.service';
import { OrderCreateRequest } from '../model/order.model';
import { Fdc3InteropService, Fdc3InboundEvent } from '../service/fdc3-interop.service';

@Component({
    standalone: false,
    selector: 'app-trade',
    templateUrl: './trade.component.html',
    styleUrls: ['./trade.component.scss']
})
export class TradeComponent implements OnInit, OnDestroy {
    @ViewChild('ticketComponent') tradeTicketTemplate?: TemplateRef<any>;
    @ViewChild('orderTicketComponent') orderTicketTemplate?: TemplateRef<any>;

    private readonly allAccountsOption: Account = {
        id: 0,
        displayName: 'All Accounts'
    };
    accounts: Account[] = [];
    realAccounts: Account[] = [];
    accountIds: number[] = [];
    accountNameById: { [accountId: number]: string } = {};
    accountModel?: Account = undefined;
    stocks: Stock[] = [];
    modalRef?: BsModalRef;
    createTicketResponse: any;
    createOrderResponse: any;
    activeBlotter: 'trades' | 'orders' = 'trades';
    portfolioSummary: PortfolioSummary = {
        totalMarketValue: 0,
        totalCostBasis: 0,
        totalPnl: 0
    };
    accountSummary: PortfolioSummary = {
        totalMarketValue: 0,
        totalCostBasis: 0,
        totalPnl: 0
    };
    allAccountsSummary: PortfolioSummary = {
        totalMarketValue: 0,
        totalCostBasis: 0,
        totalPnl: 0
    };
    tradeTicketPresetSecurity = '';
    orderTicketPresetSecurity = '';
    allPositions: Position[] = [];
    private readonly marketPriceByTicker = new Map<string, number>();
    private priceStreamUnsubscribeFn?: Function;
    private readonly interopSubscriptions = new Subscription();
    private account = new Subject<Account>();

    constructor(private accountService: AccountService,
        private symbolService: SymbolService,
        private orderAdminService: OrderAdminService,
        private positionService: PositionService,
        private tradeFeed: TradeFeedService,
        private modalService: BsModalService,
        private fdc3Interop: Fdc3InteropService) { }

    ngOnInit(): void {
        this.accountService.getAccounts().subscribe((accounts) => {
            this.realAccounts = accounts;
            this.accountNameById = this.realAccounts.reduce((acc, account) => {
                acc[account.id] = account.displayName;
                return acc;
            }, {} as { [accountId: number]: string });
            this.accountIds = this.realAccounts.map((account) => account.id);
            this.accounts = [this.allAccountsOption, ...this.realAccounts];
            this.setAccount(this.realAccounts[5] ?? this.realAccounts[0] ?? this.allAccountsOption);
        });
        this.symbolService.getStocks().subscribe((stocks) => this.stocks = stocks);
        this.loadAllPositions();
        this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (tick: PriceTick) => {
            if (!tick?.ticker || tick.price == null) {
                return;
            }
            this.marketPriceByTicker.set(tick.ticker, Number(tick.price));
            this.recomputeAllAccountsSummary();
        });

        this.initializeFdc3Interop();
    }

    onAccountChange(account: Account) {
        account && this.setAccount(account);
    }

    getAccountName(item: Account) {
        return item.displayName;
    }

    openTicket(template: TemplateRef<any>) {
        if (this.isAllAccountsSelected) {
            return;
        }
        this.modalRef = this.modalService.show(template);
    }

    openOrderTicket(template: TemplateRef<any>) {
        if (this.isAllAccountsSelected) {
            return;
        }
        this.modalRef = this.modalService.show(template);
    }

    createTradeTicket(ticket: TradeTicket) {
        if (this.isAllAccountsSelected) {
            this.createTicketResponse = { success: false, message: 'Select a specific account to create a trade.' };
            return;
        }
        this.symbolService.createTicket(ticket).subscribe((response) => {
            this.createTicketResponse = response;
            this.loadAllPositions();
        });
        this.closeTicket();
    }

    createOrderTicket(ticket: OrderCreateRequest) {
        if (this.isAllAccountsSelected) {
            this.createOrderResponse = { success: false, message: 'Select a specific account to create an order.' };
            return;
        }
        this.orderAdminService.createOrder(ticket).subscribe({
            next: (response) => {
                this.createOrderResponse = {
                    success: true,
                    message: `Order ${response.orderId} created.`,
                    payload: response
                };
                this.activeBlotter = 'orders';
            },
            error: (error) => {
                this.createOrderResponse = {
                    success: false,
                    message: error?.error?.error ?? error?.message ?? 'Failed to create order.'
                };
            }
        });
        this.closeTicket();
    }

    closeTicket() {
        this.tradeTicketPresetSecurity = '';
        this.orderTicketPresetSecurity = '';
        this.modalRef?.hide();
    }

    onCloseAlert() {
        this.createTicketResponse = undefined;
    }

    onCloseOrderAlert() {
        this.createOrderResponse = undefined;
    }

    onSummaryChange(summary: PortfolioSummary) {
        this.accountSummary = summary;
        this.portfolioSummary = this.isAllAccountsSelected ? this.allAccountsSummary : summary;
    }

    setBlotterMode(mode: 'trades' | 'orders') {
        this.activeBlotter = mode;
    }

    private setAccount(account: Account) {
        this.accountModel = account;
        this.account.next(account);
        this.accountSummary = {
            totalMarketValue: 0,
            totalCostBasis: 0,
            totalPnl: 0
        };
        this.portfolioSummary = {
            totalMarketValue: 0,
            totalCostBasis: 0,
            totalPnl: 0
        };
    }

    get isAllAccountsSelected(): boolean {
        return (this.accountModel?.id ?? -1) === this.allAccountsOption.id;
    }

    ngOnDestroy(): void {
        this.priceStreamUnsubscribeFn?.();
        this.interopSubscriptions.unsubscribe();
    }

    async onSecuritySelected(security: string): Promise<void> {
        const normalized = String(security || '').trim().toUpperCase();
        if (!normalized) {
            return;
        }
        const published = await this.fdc3Interop.publishTickerSelection(normalized);
        if (!published) {
            console.warn('[fdc3] failed to broadcast instrument context', { ticker: normalized });
        }
    }

    private loadAllPositions() {
        this.positionService.getAllPositions().subscribe((positions: Position[]) => {
            this.allPositions = positions ?? [];
            this.recomputeAllAccountsSummary();
        });
    }

    private recomputeAllAccountsSummary() {
        const totals: PortfolioSummary = {
            totalMarketValue: 0,
            totalCostBasis: 0,
            totalPnl: 0
        };

        for (const position of this.allPositions) {
            const quantity = Number((position as any).quantity ?? 0);
            const averageCostBasis = Number((position as any).averageCostBasis ?? (position as any).averagecostbasis ?? 0);
            const security = String((position as any).security ?? '');
            const marketPrice = Number(this.marketPriceByTicker.get(security) ?? averageCostBasis);
            const marketValue = quantity * marketPrice;
            const costBasisValue = quantity * averageCostBasis;
            totals.totalMarketValue += marketValue;
            totals.totalCostBasis += costBasisValue;
            totals.totalPnl += (marketValue - costBasisValue);
        }

        this.allAccountsSummary = totals;
        if (this.isAllAccountsSelected) {
            this.accountSummary = totals;
            this.portfolioSummary = totals;
        }
    }

    private initializeFdc3Interop(): void {
        this.interopSubscriptions.add(
            this.fdc3Interop.inboundEvents$.subscribe((event) => {
                this.handleInboundInteropEvent(event);
            })
        );
    }

    private handleInboundInteropEvent(event: Fdc3InboundEvent): void {
        const normalized = String(event?.ticker || '').trim().toUpperCase();
        if (!normalized) {
            return;
        }

        if (event.action === 'ViewOrders') {
            this.activeBlotter = 'orders';
            return;
        }

        if (event.action === 'TraderX.CreateTradeTicket') {
            this.activeBlotter = 'trades';
            this.ensureSpecificAccountSelected();
            this.tradeTicketPresetSecurity = normalized;
            if (this.tradeTicketTemplate && !this.isAllAccountsSelected) {
                this.modalRef = this.modalService.show(this.tradeTicketTemplate);
            }
            return;
        }

        if (event.action === 'TraderX.CreateOrderTicket') {
            this.activeBlotter = 'orders';
            this.ensureSpecificAccountSelected();
            this.orderTicketPresetSecurity = normalized;
            if (this.orderTicketTemplate && !this.isAllAccountsSelected) {
                this.modalRef = this.modalService.show(this.orderTicketTemplate);
            }
        }
    }

    private ensureSpecificAccountSelected(): void {
        if (!this.isAllAccountsSelected) {
            return;
        }
        const firstRealAccount = this.realAccounts[0];
        if (firstRealAccount) {
            this.setAccount(firstRealAccount);
        }
    }
}
