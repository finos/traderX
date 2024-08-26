import { Component, Input, Output, EventEmitter, OnInit } from '@angular/core';
import { TradeTicket, TradePrice } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { SymbolService } from '../../service/symbols.service';

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
  filteredStocks: Stock[] = [];

  constructor(private symbolService: SymbolService) { }

  ngOnInit() {
    this.ticket = {
      quantity: 0,
      accountId: this.account?.id || 0,
      side: 'Buy',
      security: '',
      unitPrice: 0
    };

    this.filteredStocks = this.stocks;
  }


  onSelect(e: TypeaheadMatch): void {
    console.log('Selected value: ', e.value);
    this.ticket.security = e.item.ticker;
    this.symbolService.getPrice(e.item.ticker).subscribe(
      (price: TradePrice) => this.ticket.unitPrice = price.price);
  }

  onBlur(): void {
    if (this.selectedCompany) return;
    this.ticket.security = '';
    this.ticket.unitPrice = 0;
  }

  onCreate() {
    if (!this.ticket.security || !this.ticket.quantity) {
      console.warn('Either security is not selected or quanity is not set!')
      return;
    }
    this.create.emit(this.ticket);
  }

  onCancel() {
    this.cancel.emit();
  }
}
