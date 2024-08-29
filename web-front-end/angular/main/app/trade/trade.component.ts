import { Component, OnInit, TemplateRef } from '@angular/core';
import { Subject } from 'rxjs';
import { Position, TradeTicket } from '../model/trade.model';
import { Account } from '../model/account.model';
import { AccountService } from '../service/account.service';
import { Stock } from '../model/symbol.model';
import { SymbolService } from '../service/symbols.service';
import { PositionService } from '../service/position.service';
import { BsModalService, BsModalRef } from 'ngx-bootstrap/modal';

@Component({
    selector: 'app-trade',
    templateUrl: './trade.component.html',
    styleUrls: ['./trade.component.scss']
})
export class TradeComponent implements OnInit {
    accounts: Account[] = [];
    accountModel?: Account = undefined;
    stocks: Stock[] = [];
    positions: Position[] = [];
    modalRef?: BsModalRef;
    createTicketResponse: any;
    private account = new Subject<Account>();

    constructor(private accountService: AccountService,
        private symbolService: SymbolService,
        private modalService: BsModalService,
        private positionService: PositionService) { }

    ngOnInit(): void {
        this.accountService.getAccounts().subscribe((accounts) => {
            console.log('TradeComponent init', accounts);
            this.accounts = accounts;
            this.setAccount(this.accounts[5]);
            this.positionService.getPositions(this.accounts[5].id).subscribe((positions) => {
              this.positions = positions;
              console.log('TradeComponent, positions:', this.positions);
          });
        });
        this.symbolService.getStocks().subscribe((stocks) => this.stocks = stocks);
    }

    onAccountChange(account: Account) {
        console.log('onAccountChange', arguments);
        account && this.setAccount(account);
        account && this.positionService.getPositions(account.id).subscribe((positions) => {
            this.positions = positions;
            console.log(this.positions);
        });
    }

    getAccountName(item: Account) {
        return item.displayName;
    }

    openTicket(template: TemplateRef<any>) {
        this.modalRef = this.modalService.show(template);
    }

    createTradeTicket(ticket: TradeTicket) {
        console.log('createTradeTicket', ticket);
        this.symbolService.createTicket(ticket).subscribe((response) => {
            console.log(response);
            this.createTicketResponse = response;
        });
        this.closeTicket();
    }

    closeTicket() {
        this.modalRef?.hide();
    }

    onCloseAlert() {
        this.createTicketResponse = undefined;
    }

    private setAccount(account: Account) {
        this.accountModel = account;
        this.account.next(account);
    }
}
