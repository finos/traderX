import * as fs from 'fs';
const CsvReadableStream = require('csv-reader');
import { Stock } from '../stocks/interfaces/stock.interface';

export async function loadCsvData() {
    const promise = new Promise<Stock[]>((resolve) => {
        const stocks: Stock[] = [];
        let isHeaderRow = true;
        fs.createReadStream('./data/s-and-p-500-companies.csv', 'utf8')
            .pipe(new CsvReadableStream({ trim: true }))
            .on('data', function (row) {
                if (isHeaderRow === true) {
                    isHeaderRow = false;
                } else {
                    stocks.push({ ticker: row[0], companyName: row[1] });
                }
            })
            .on('end', function () {
                resolve(stocks);
            });
    });
    return promise;
}