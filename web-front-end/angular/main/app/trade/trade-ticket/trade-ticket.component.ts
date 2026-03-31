import { Component, Input, Output, EventEmitter, OnInit } from '@angular/core';
import { TradeTicket } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';

@Component({
  selector: 'app-trade-ticket',
  templateUrl: './trade-ticket.component.html',
  styleUrls: ['./trade-ticket.component.scss']
})
export class TradeTicketComponent implements OnInit {

  @Input() stocks: Stock[];
  @Input() account: Account | undefined;

  @Output() create = new EventEmitter<TradeTicket>();
  @Output() cancel = new EventEmitter();

  selectedCompany?: string = undefined;
  ticket: TradeTicket;
  filteredStocks: Array<Stock & { matchLabel: string }> = [];

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
  }


  onSelect(e: TypeaheadMatch): void {
    console.log('Selected value: ', e.value);
    const selectedStock = e.item as Stock & { matchLabel?: string };
    this.ticket.security = selectedStock.ticker;
    this.selectedCompany = selectedStock.matchLabel || this.toMatchLabel(selectedStock);
  }

  onBlur(): void {
    if (this.selectedCompany) return;
    this.ticket.security = '';
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

  private toMatchLabel(stock: Stock): string {
    return `${stock.ticker} - ${stock.companyName}`;
  }
}
