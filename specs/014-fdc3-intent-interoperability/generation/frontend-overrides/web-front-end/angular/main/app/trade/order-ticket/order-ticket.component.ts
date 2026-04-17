import { Component, Input, Output, EventEmitter, OnChanges, OnInit, OnDestroy, SimpleChanges } from '@angular/core';
import { PriceTick } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { TradeFeedService } from 'main/app/service/trade-feed.service';
import { OrderCreateRequest } from 'main/app/model/order.model';

@Component({
  standalone: false,
  selector: 'app-order-ticket',
  templateUrl: './order-ticket.component.html',
  styleUrls: ['./order-ticket.component.scss']
})
export class OrderTicketComponent implements OnInit, OnChanges, OnDestroy {
  @Input() stocks: Stock[] = [];
  @Input() account: Account | undefined;
  @Input() presetSecurity = '';
  @Output() create = new EventEmitter<OrderCreateRequest>();
  @Output() cancel = new EventEmitter<void>();

  selectedCompany?: string = undefined;
  ticket: OrderCreateRequest = {
    accountId: 0,
    security: '',
    side: 'Buy',
    quantity: 0,
    limitPrice: 0
  };
  filteredStocks: Array<Stock & { matchLabel: string }> = [];
  selectedPrice: number | null = null;
  selectedPriceAsOf: string | null = null;
  private selectedPriceTicker: string | null = null;
  private priceStreamUnsubscribeFn?: Function;

  constructor(private tradeFeed: TradeFeedService) {}

  ngOnInit() {
    this.ticket.accountId = this.account?.id || 0;
    this.filteredStocks = (this.stocks || []).map((stock) => ({
      ...stock,
      matchLabel: this.toMatchLabel(stock)
    }));
    this.applyPresetSecurity(this.presetSecurity);
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes.stocks) {
      this.filteredStocks = (this.stocks || []).map((stock) => ({
        ...stock,
        matchLabel: this.toMatchLabel(stock)
      }));
    }
    if (changes.account) {
      this.ticket.accountId = this.account?.id || 0;
    }
    if (changes.presetSecurity) {
      this.applyPresetSecurity(changes.presetSecurity.currentValue);
    }
  }

  ngOnDestroy() {
    this.priceStreamUnsubscribeFn?.();
  }

  onSelect(e: TypeaheadMatch): void {
    const selectedStock = e.item as Stock & { matchLabel?: string };
    this.ticket.security = selectedStock.ticker;
    this.selectedCompany = selectedStock.matchLabel || this.toMatchLabel(selectedStock);
    this.subscribeToTickerPrice(selectedStock.ticker);
  }

  onBlur(): void {
    if (this.selectedCompany) {
      return;
    }
    this.ticket.security = '';
    this.selectedPrice = null;
    this.selectedPriceAsOf = null;
    this.selectedPriceTicker = null;
    this.priceStreamUnsubscribeFn?.();
    this.priceStreamUnsubscribeFn = undefined;
  }

  onCreate() {
    if (!this.ticket.security || this.ticket.quantity <= 0 || this.ticket.limitPrice <= 0) {
      console.warn('Order ticket is incomplete');
      return;
    }
    this.create.emit({
      ...this.ticket,
      security: this.ticket.security.toUpperCase()
    });
  }

  onCancel() {
    this.cancel.emit();
  }

  formatLivePrice(): string {
    if (this.selectedPrice == null) {
      return 'Streaming...';
    }
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 3,
      maximumFractionDigits: 3
    }).format(this.selectedPrice);
  }

  formatAsOf(): string {
    if (!this.selectedPriceAsOf) {
      return '';
    }
    const ts = new Date(this.selectedPriceAsOf);
    if (Number.isNaN(ts.getTime())) {
      return '';
    }
    return ts.toLocaleTimeString();
  }

  private subscribeToTickerPrice(ticker: string): void {
    if (!ticker) {
      return;
    }
    if (this.selectedPriceTicker === ticker && this.priceStreamUnsubscribeFn) {
      return;
    }
    this.priceStreamUnsubscribeFn?.();
    this.selectedPrice = null;
    this.selectedPriceAsOf = null;
    this.selectedPriceTicker = ticker;

    this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe(`pricing.${ticker}`, (tick: PriceTick) => {
      if (!tick || tick.ticker !== ticker) {
        return;
      }
      this.selectedPrice = Number(tick.price);
      this.selectedPriceAsOf = tick.asOf ?? null;
      if (!this.ticket.limitPrice || this.ticket.limitPrice <= 0) {
        this.ticket.limitPrice = Number(tick.price);
      }
    });
  }

  private toMatchLabel(stock: Stock): string {
    return `${stock.ticker} - ${stock.companyName}`;
  }

  private applyPresetSecurity(rawSecurity: string): void {
    const normalized = String(rawSecurity || '').trim().toUpperCase();
    if (!normalized) {
      return;
    }
    const matched = (this.stocks || []).find((stock) => String(stock.ticker || '').toUpperCase() === normalized);
    if (matched) {
      this.ticket.security = matched.ticker;
      this.selectedCompany = this.toMatchLabel(matched);
      this.subscribeToTickerPrice(matched.ticker);
      return;
    }
    this.ticket.security = normalized;
    this.selectedCompany = normalized;
    this.subscribeToTickerPrice(normalized);
  }
}
