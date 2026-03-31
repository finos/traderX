import * as fs from 'fs';
const CsvReadableStream = require('csv-reader');
import { Stock } from '../stocks/stock.model';

export interface StockLoadOptions {
  supportedTickers?: Set<string>;
  maxTickers?: number;
}

const SUPPLEMENTAL_SAMPLE_STOCKS: Stock[] = [
  { ticker: 'MS', companyName: 'Morgan Stanley' },
  { ticker: 'UBS', companyName: 'UBS Group AG' },
  { ticker: 'C', companyName: 'Citigroup Inc.' },
  { ticker: 'GS', companyName: 'Goldman Sachs Group, Inc.' },
  { ticker: 'DB', companyName: 'Deutsche Bank AG' },
  { ticker: 'JPM', companyName: 'JPMorgan Chase & Co.' },
  { ticker: 'COF', companyName: 'Capital One Financial Corporation' },
  { ticker: 'DFS', companyName: 'Discover Financial Services' },
  { ticker: 'FNMA', companyName: 'Fannie Mae' },
  { ticker: 'FIS', companyName: 'Fidelity National Information Services, Inc.' },
  { ticker: 'FNF', companyName: 'Fidelity National Financial, Inc.' }
];

const PREFERRED_COMPANY_NAME_BY_TICKER: Record<string, string> = {
  MS: 'Morgan Stanley',
  UBS: 'UBS Group AG',
  C: 'Citigroup Inc.',
  GS: 'Goldman Sachs Group, Inc.',
  DB: 'Deutsche Bank AG',
  JPM: 'JPMorgan Chase & Co.',
  COF: 'Capital One Financial Corporation',
  DFS: 'Discover Financial Services',
  FNMA: 'Fannie Mae',
  FIS: 'Fidelity National Information Services, Inc.',
  FNF: 'Fidelity National Financial, Inc.',
  META: 'Meta Platforms, Inc.'
};

export async function loadCsvData(options: StockLoadOptions = {}): Promise<Stock[]> {
  const supportedTickers = options.supportedTickers;
  const maxTickers = Number(options.maxTickers ?? 0);
  const seenTickers = new Set<string>();

  return new Promise<Stock[]>((resolve) => {
    const stocks: Stock[] = [];
    let isHeaderRow = true;
    fs.createReadStream('./data/s-and-p-500-companies.csv', 'utf8')
      .pipe(new CsvReadableStream({ trim: true }))
      .on('data', (row: string[]) => {
        if (isHeaderRow) {
          isHeaderRow = false;
          return;
        }
        const rawTicker = String(row[0] ?? '').trim().toUpperCase();
        const ticker = rawTicker === 'FB' ? 'META' : rawTicker;
        if (!ticker) {
          return;
        }
        if (supportedTickers && !supportedTickers.has(ticker)) {
          return;
        }
        if (!seenTickers.has(ticker)) {
          const companyName = PREFERRED_COMPANY_NAME_BY_TICKER[ticker] ?? row[1];
          stocks.push({ ticker, companyName });
          seenTickers.add(ticker);
        }
      })
      .on('end', () => {
        for (const stock of SUPPLEMENTAL_SAMPLE_STOCKS) {
          if (supportedTickers && !supportedTickers.has(stock.ticker)) {
            continue;
          }
          if (seenTickers.has(stock.ticker)) {
            continue;
          }
          stocks.push(stock);
          seenTickers.add(stock.ticker);
        }
        if (maxTickers > 0) {
          resolve(stocks.slice(0, maxTickers));
          return;
        }
        resolve(stocks);
      });
  });
}
