import { Account } from '../model/account.model';
import { User } from '../model/user.model';
import { faker } from '@faker-js/faker';
import { Stock } from '../model/symbol.model';
import { Trade, State, Side, Position } from '../model/trade.model';

export function sleep(delay = 0) {
  return new Promise((re) => setTimeout(re, delay));
}

export function createUser(): User {
  return {
    fullName: faker.name.firstName(),
    email: faker.internet.email(),
    department: faker.commerce.department(),
    logonId: faker.random.alphaNumeric(5),
    employeeId: faker.random.alpha(5),
    photoUrl: 'testurl'
  };
}

export function createAccount(): Account {
  return {
    displayName: faker.company.name(),
    id: faker.datatype.number()
  };
}

export function createStock(): Stock {
  return {
    companyName: faker.company.name(),
    ticker: faker.random.alpha(4)
  };
}

export function createTrade(): Trade {
  return {
    created: faker.date.recent(),
    id: faker.random.alpha(5),
    state: State.Pending,
    side: Side.Buy,
    ...createPosition()
  };
}

export function createPosition(): Position {
  return {
    accountid: faker.datatype.number(),
    quantity: faker.datatype.number(100),
    security: faker.random.alpha(4),
    updated: faker.date.recent()
  };
}
