import { Component, OnDestroy, OnInit, TemplateRef } from '@angular/core';
import { Subject } from 'rxjs';
import { PortfolioSummary, PriceTick, TradeTicket, Position } from '../model/trade.model';
import { OrderCreateRequest } from '../model/order.model';
import { Account } from '../model/account.model';
import { AccountService } from '../service/account.service';
import { Stock } from '../model/symbol.model';
import { SymbolService } from '../service/symbols.service';
import { BsModalService, BsModalRef } from 'ngx-bootstrap/modal';
import { OrderAdminService } from '../service/order-admin.service';
import { PositionService } from '../service/position.service';
import { TradeFeedService } from '../service/trade-feed.service';

@Component({
    standalone: false,
    selector: 'app-trade',
    templateUrl: './trade.component.html',
    styleUrls: ['./trade.component.scss']
})
export class TradeComponent implements OnInit, OnDestroy {
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
    selectedOrderSecurity = '';
    allPositions: Position[] = [];
    private readonly marketPriceByTicker = new Map<string, number>();
    private priceStreamUnsubscribeFn?: () => void;
    private account = new Subject<Account>();

    constructor(private accountService: AccountService,
        private symbolService: SymbolService,
        private orderAdminService: OrderAdminService,
        private positionService: PositionService,
        private tradeFeed: TradeFeedService,
        private modalService: BsModalService) { }

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
            console.log(this.accounts);
        });
        this.symbolService.getStocks().subscribe((stocks) => this.stocks = stocks);
        this.loadAllPositions();
        this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (tick: PriceTick) => {
            const ticker = this.normalizeTicker(tick?.ticker);
            if (!ticker || tick.price == null) {
                return;
            }
            this.marketPriceByTicker.set(ticker, Number(tick.price));
            this.recomputeAllAccountsSummary();
        });
    }

    onAccountChange(account: Account) {
        console.log('onAccountChange', arguments);
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
        console.log('createTradeTicket', ticket);
        this.symbolService.createTicket(ticket).subscribe((response) => {
            console.log(response);
            this.createTicketResponse = response;
            this.loadAllPositions();
        });
        this.closeTicket();
    }

    createOrderTicket(order: OrderCreateRequest) {
        if (this.isAllAccountsSelected) {
            this.createOrderResponse = { success: false, message: 'Select a specific account to create an order.' };
            return;
        }
        this.orderAdminService.createOrder(order).subscribe((response) => {
            this.createOrderResponse = response;
            this.activeBlotter = 'orders';
        });
        this.closeTicket();
    }

    onOrderSecuritySelected(security: string) {
        this.selectedOrderSecurity = String(security || '').trim().toUpperCase();
    }

    closeTicket() {
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
    }

    private normalizeTicker(ticker: string | undefined): string {
        return String(ticker || '').trim().toUpperCase();
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
            const pricingPosition = position as Position & { averagecostbasis?: number };
            const quantity = Number(position.quantity ?? 0);
            const averageCostBasis = Number(pricingPosition.averageCostBasis ?? pricingPosition.averagecostbasis ?? 0);
            const security = this.normalizeTicker(position.security);
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
}
