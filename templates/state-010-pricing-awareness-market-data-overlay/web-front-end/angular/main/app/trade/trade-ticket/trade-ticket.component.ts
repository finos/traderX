import { Component, Input, Output, EventEmitter, OnInit, OnDestroy } from '@angular/core';
import { PriceTick, TradeTicket } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

@Component({
  selector: 'app-trade-ticket',
  templateUrl: './trade-ticket.component.html',
  styleUrls: ['./trade-ticket.component.scss']
})
export class TradeTicketComponent implements OnInit, OnDestroy {

  @Input() stocks: Stock[];
  @Input() account: Account | undefined;

  @Output() create = new EventEmitter<TradeTicket>();
  @Output() cancel = new EventEmitter();

  selectedCompany?: string = undefined;
  ticket: TradeTicket;
  filteredStocks: Stock[] = [];
  selectedPrice: number | null = null;
  selectedPriceAsOf: string | null = null;
  private selectedPriceTicker: string | null = null;
  private priceStreamUnsubscribeFn?: Function;

  constructor(private tradeFeed: TradeFeedService) {}

  ngOnInit() {
    this.ticket = {
      quantity: 0,
      accountId: this.account?.id || 0,
      side: 'Buy',
      security: ''
    };

    this.filteredStocks = this.stocks;
  }

  ngOnDestroy() {
    this.priceStreamUnsubscribeFn?.();
  }

  onSelect(e: TypeaheadMatch): void {
    console.log('Selected value: ', e.value);
    this.ticket.security = e.item.ticker;
    this.subscribeToTickerPrice(e.item.ticker);
  }

  onBlur(): void {
    if (this.selectedCompany) return;
    this.ticket.security = '';
    this.selectedPrice = null;
    this.selectedPriceAsOf = null;
    this.selectedPriceTicker = null;
    this.priceStreamUnsubscribeFn?.();
    this.priceStreamUnsubscribeFn = undefined;
  }

  onCreate() {
    if (!this.ticket.security || !this.ticket.quantity) {
      console.warn('Either security is not selected or quanity is not set!')
      return;
    }
    console.log('create tradeTicket', this.ticket);
    this.create.emit(this.ticket);
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
    });
  }
}
