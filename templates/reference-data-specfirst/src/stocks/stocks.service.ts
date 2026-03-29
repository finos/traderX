import { Injectable } from '@nestjs/common';
import { loadCsvData } from '../data-loader/load-csv-data';
import { Stock } from './stock.model';

@Injectable()
export class StocksService {
  private readonly stocks: Promise<Stock[]>;

  constructor() {
    this.stocks = loadCsvData();
  }

  async findAll(): Promise<Stock[]> {
    return this.stocks;
  }

  async findByTicker(ticker: string): Promise<Stock | undefined> {
    return (await this.stocks).find((stock) => stock.ticker === ticker);
  }
}
