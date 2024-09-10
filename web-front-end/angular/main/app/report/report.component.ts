import { Component, OnInit, TemplateRef } from '@angular/core';
import { Subject } from 'rxjs';
import { Account } from '../model/account.model';
import { TradeInterval, TradePointInTime } from '../model/trade.model';
import { AccountService } from '../service/account.service';
import { Stock } from '../model/symbol.model';
import { SymbolService } from '../service/symbols.service';
import { TradeFeedService } from 'main/app/service/trade-feed.service';
import { PriceService } from '../service/price.service';

@Component({
    selector: 'app-report',
    templateUrl: './report.component.html',
    styleUrls: ['./report.component.scss']
})
export class ReportComponent implements OnInit {

  accounts: Account[] = [];
  accountModel?: Account = undefined;
  stocks: Stock[] = [];
  intervals: TradeInterval[] = [];
  intervalModel?: TradeInterval = undefined;
  createTicketResponse: any;
  private account = new Subject<Account>();
  private interval = new Subject<TradeInterval>();

  constructor(private accountService: AccountService,
      private symbolService: SymbolService,
      private priceService: PriceService,
      private tradeFeed: TradeFeedService) { }

  ngOnInit(): void {
    this.accountService.getAccounts().subscribe((accounts) => {
        console.log('ReportComponent init', accounts);
        this.accounts = accounts;
        this.setAccount(this.accounts[5]);
    });
    this.symbolService.getStocks().subscribe((stocks) => this.stocks = stocks);
  }

  onAccountChange(account: Account) {
    console.log('onAccountChange', arguments);
    account && this.setAccount(account);
}

  getAccountName(item: Account) {
      return item.displayName;
  }

  onIntervalChange(interval: TradeInterval) {
    interval && this.setInterval(interval);
  }

  private setAccount(account: Account) {
    this.accountModel = account;
    this.account.next(account);
    this.tradeFeed.emit('/account', account.id);
    this.priceService.getTradeIntervals(account.id).subscribe((intervals: TradeInterval[]) => {
      this.intervals = intervals.map((i) =>
        Object.assign(i, { label: `${i.start} - ${i.end ? i.end : '...'}` })
      );
      console.log('Report Comp : Trade intervals', this.intervals);

      intervals.length > 0 && this.setInterval(this.intervals[0]);
    });
  }

  private setInterval(interval: TradeInterval) {
    console.log('setInterval', interval);
    this.intervalModel = interval;
    this.interval.next(interval);
  }
}
