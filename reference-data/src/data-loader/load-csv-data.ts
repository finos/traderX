import * as fs from 'fs';
const CsvReadableStream = require('csv-reader');
import { Stock } from '../stocks/stock.model';

export async function loadCsvData(): Promise<Stock[]> {
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
        stocks.push({ ticker: row[0], companyName: row[1] });
      })
      .on('end', () => resolve(stocks));
  });
}
