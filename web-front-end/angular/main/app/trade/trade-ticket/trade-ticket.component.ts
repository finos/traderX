import { Component, Input, Output, EventEmitter, OnInit } from '@angular/core';
import { TradeTicket, TradePrice, Position } from 'main/app/model/trade.model';
import { Stock } from 'main/app/model/symbol.model';
import { Account } from 'main/app/model/account.model';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { SymbolService } from '../../service/symbols.service';
import { PositionService } from '../../service/position.service';


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
  sellDisabled = true;
  position?: Position = undefined;
  positions: Position[] = [];

  constructor(private symbolService: SymbolService, private positionService: PositionService) { }

  ngOnInit() {
    this.ticket = {
      quantity: 0,
      accountId: this.account?.id || 0,
      side: 'Buy',
      security: '',
      unitPrice: 0
    };

    this.filteredStocks = this.stocks;

    this.positionService.getPositions(this.account?.id || 0).subscribe((positions) => {
      this.positions = positions;
      console.log(this.positions);
    });
  }

  maxQuantity() {
    return this.position && this.ticket.side == 'Sell' ?
      this.position?.quantity : Number.MAX_SAFE_INTEGER;
  }

  hasErrors() {
    return !this.ticket.security || !this.ticket.quantity || this.ticket.quantity > this.maxQuantity();
  }

  onSelect(e: TypeaheadMatch): void {
    console.log('Selected value: ', e.value);
    console.log('Positions: ', this.positions);
    this.ticket.security = e.item.ticker;
    this.position = this.positions.find((p) => p.security === this.ticket.security);
    if (this.position) {
      console.log('Position found: ', this.position);
      this.sellDisabled = false;
    } else {
      console.log('Position not found!');
      this.sellDisabled = true;
    }
    this.symbolService.getPrice(e.item.ticker).subscribe(
      (price: TradePrice) => this.ticket.unitPrice = price.price);
  }

  onBlur(): void {
    if (this.selectedCompany) return;
    this.ticket.security = '';
    this.ticket.unitPrice = 0;
  }

  onCreate() {
    if (this.hasErrors()) {
      console.warn('Either security is not selected, quanity is not set or trying to sell more than you have!')
      return;
    }
    this.create.emit(this.ticket);
  }

  onCancel() {
    this.cancel.emit();
  }
}
