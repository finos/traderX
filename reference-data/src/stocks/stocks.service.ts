import { Injectable } from '@nestjs/common';
import { loadCsvData } from '../data-loader/load-csv-data';
import { Stock } from './stock.model';

@Injectable()
export class StocksService {
  private readonly stocks: Promise<Stock[]>;

  constructor() {
    const supportedTickers = this.parseSupportedTickers(
      process.env.REFERENCE_DATA_SUPPORTED_TICKERS
    );
    const maxTickers = this.parsePositiveInt(process.env.REFERENCE_DATA_MAX_TICKERS);
    this.stocks = loadCsvData({ supportedTickers, maxTickers });
  }

  async findAll(): Promise<Stock[]> {
    return this.stocks;
  }

  async findByTicker(ticker: string): Promise<Stock | undefined> {
    return (await this.stocks).find((stock) => stock.ticker === ticker);
  }

  private parseSupportedTickers(input?: string): Set<string> | undefined {
    const raw = String(input ?? '').trim();
    if (!raw) {
      return undefined;
    }
    const tickers = raw
      .split(',')
      .map((ticker) => ticker.trim().toUpperCase())
      .filter(Boolean);
    if (tickers.length === 0) {
      return undefined;
    }
    return new Set(tickers);
  }

  private parsePositiveInt(input?: string): number | undefined {
    const parsed = Number(input);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      return undefined;
    }
    return parsed;
  }
}
