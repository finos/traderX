import { Injectable } from '@nestjs/common';
import { Stock } from './interfaces/stock.interface';
import { loadCsvData } from '../data-loader/load-csv-data';

@Injectable()
export class StocksService {
    stocks: Promise<Stock[]>;

    constructor() {
        this.stocks = loadCsvData();
    }

    async findAll() {
        return await this.stocks;
    }

    async findByTicker(ticker: string) {
        return (await this.stocks).find((stock) => stock.ticker === ticker);
    }
}