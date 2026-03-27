import { Observable, of } from 'rxjs';
import { Account } from '../model/account.model';
import { AccountUser, User } from '../model/user.model';
import { createAccount, createUser, createStock, createTrade, createPosition } from './utils';
import { Stock } from '../model/symbol.model';
import { Trade, Position, TradeTicket } from '../model/trade.model';

export const accounts: Account[] = Array.from({ length: 5 }, () => createAccount());
export const stocks: Stock[] = Array.from({ length: 5 }, () => createStock());
export const trades: Trade[] = Array.from({ length: 2 }, () => createTrade());
export const positions: Position[] = Array.from({ length: 2 }, () => createPosition());
const users: User[] = Array.from({ length: 5 }, () => createUser());
const accountUsers: AccountUser[] = accounts.map((ac, index) => {
  const idx = Math.floor(Math.random() * (accounts.length - index));
  return { accountId: ac.id, username: users[idx].fullName };
});

export class MockAccountService {
  addAccountUser(accountUser: AccountUser) {
    return of<AccountUser>(accountUser);
  }

  addAccount(account: Partial<Account>) {
    return of<Account>({ displayName: account.displayName || '', id: 1 });
  }

  getAccounts() {
    return of<Account[]>(accounts);
  }

  getAccountUsers(): Observable<AccountUser[]> {
    return of<AccountUser[]>(accountUsers);
  }
}

export class MockUserService {
  getUsers(searchText: string) {
    const src = [{ fullName: 'Jhon mac' }, { fullName: 'Tom san' }, { fullName: 'Merry san' }] as User[];
    return of<any>({ people: src.filter((u) => u.fullName.indexOf(searchText) !== -1) });
  }
}

export class MockTradeService {

  getTrades(account_id: number): Observable<Trade[]> {
    return of(trades);
  }

  getPositions(account_id: number): Observable<Position[]> {
    return of(positions);
  }
}

export class MockSymbolService {

  getStocks() {
    return of(stocks);
  }

  createTicket(ticket: TradeTicket) {
    console.log('dummy create ticket called');
    return of({});
  }

}

export class MockTradeFeedService {

  subscribe(topic: string, callback: Function) {
  }

  unSubscribe() {
  }

}
