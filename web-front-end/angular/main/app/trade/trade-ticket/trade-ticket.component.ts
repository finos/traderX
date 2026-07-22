import { Component, Input, Output, EventEmitter, OnChanges, OnInit, OnDestroy, SimpleChanges } from '@angular/core';
import { PriceTick, TradeTicket } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { TradeFeedService } from 'main/app/service/trade-feed.service';
import { PriceSnapshotService } from 'main/app/service/price-snapshot.service';

@Component({
    standalone: false,
  selector: 'app-trade-ticket',
  templateUrl: './trade-ticket.component.html',
  styleUrls: ['./trade-ticket.component.scss']
})
export class TradeTicketComponent implements OnInit, OnChanges, OnDestroy {

  @Input() stocks: Stock[];
  @Input() account: Account | undefined;
  @Input() presetSecurity = '';

  @Output() create = new EventEmitter<TradeTicket>();
  @Output() cancel = new EventEmitter();

  selectedCompany?: string = undefined;
  ticket: TradeTicket;
  filteredStocks: Array<Stock & { matchLabel: string }> = [];
  selectedPrice: number | null = null;
  selectedPriceAsOf: string | null = null;
  private selectedPriceTicker: string | null = null;
  private selectedPriceAsOfEpoch = 0;
  private priceStreamUnsubscribeFn?: Function;

  constructor(
    private tradeFeed: TradeFeedService,
    private priceSnapshots: PriceSnapshotService
  ) {}

  ngOnInit() {
    this.ticket = {
      quantity: 0,
      accountId: this.account?.id || 0,
      side: 'Buy',
      security: ''
    };

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
    if (changes.account && this.ticket) {
      this.ticket.accountId = this.account?.id || 0;
    }
    if (changes.presetSecurity && this.ticket) {
      this.applyPresetSecurity(changes.presetSecurity.currentValue);
    }
  }

  ngOnDestroy() {
    this.priceStreamUnsubscribeFn?.();
  }

  onSelect(e: TypeaheadMatch): void {
    console.log('Selected value: ', e.value);
    const selectedStock = e.item as Stock & { matchLabel?: string };
    this.ticket.security = selectedStock.ticker;
    this.selectedCompany = selectedStock.matchLabel || this.toMatchLabel(selectedStock);
    this.subscribeToTickerPrice(selectedStock.ticker);
  }

  onBlur(): void {
    if (this.selectedCompany) return;
    this.ticket.security = '';
    this.selectedPrice = null;
    this.selectedPriceAsOf = null;
    this.selectedPriceAsOfEpoch = 0;
    this.selectedPriceTicker = null;
    this.priceStreamUnsubscribeFn?.();
    this.priceStreamUnsubscribeFn = undefined;
  }

  onCreate() {
    if (!this.ticket.security || !this.ticket.quantity) {
      console.warn('Either security is not selected or quanity is not set!');
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
    const normalizedTicker = String(ticker || '').trim().toUpperCase();
    if (!normalizedTicker) {
      return;
    }

    if (this.selectedPriceTicker === normalizedTicker && this.priceStreamUnsubscribeFn) {
      return;
    }

    this.priceStreamUnsubscribeFn?.();
    this.selectedPrice = null;
    this.selectedPriceAsOf = null;
    this.selectedPriceAsOfEpoch = 0;
    this.selectedPriceTicker = normalizedTicker;

    this.priceSnapshots.getPrice(normalizedTicker).subscribe((snapshot) => {
      if (!snapshot) {
        return;
      }
      this.applyPriceCandidate(normalizedTicker, snapshot.price, snapshot.asOf ?? null);
    });

    this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe(`pricing.${normalizedTicker}`, (tick: PriceTick) => {
      if (!tick || String(tick.ticker || '').trim().toUpperCase() !== normalizedTicker) {
        return;
      }
      this.applyPriceCandidate(normalizedTicker, tick.price, tick.asOf ?? null);
    });
  }

  private applyPriceCandidate(ticker: string, price: number, asOf: string | null): void {
    if (this.selectedPriceTicker !== ticker) {
      return;
    }
    const numericPrice = Number(price);
    if (!Number.isFinite(numericPrice)) {
      return;
    }

    const asOfEpoch = this.toEpochMs(asOf);
    if (asOfEpoch != null) {
      if (asOfEpoch < this.selectedPriceAsOfEpoch) {
        return;
      }
      this.selectedPriceAsOfEpoch = asOfEpoch;
    } else if (this.selectedPriceAsOfEpoch > 0) {
      return;
    }

    this.selectedPrice = numericPrice;
    this.selectedPriceAsOf = asOf || null;
  }

  private toEpochMs(asOf: string | null | undefined): number | null {
    if (!asOf) {
      return null;
    }
    const ts = new Date(asOf).getTime();
    return Number.isFinite(ts) ? ts : null;
  }

  private toMatchLabel(stock: Stock): string {
    return `${stock.ticker} - ${stock.companyName}`;
  }

  private applyPresetSecurity(rawSecurity: string): void {
    const normalized = String(rawSecurity || '').trim().toUpperCase();
    if (!normalized || !this.ticket) {
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
