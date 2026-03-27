"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadCsvData = loadCsvData;
const fs = require("fs");
const CsvReadableStream = require('csv-reader');
async function loadCsvData() {
    return new Promise((resolve) => {
        const stocks = [];
        let isHeaderRow = true;
        fs.createReadStream('./data/s-and-p-500-companies.csv', 'utf8')
            .pipe(new CsvReadableStream({ trim: true }))
            .on('data', (row) => {
            if (isHeaderRow) {
                isHeaderRow = false;
                return;
            }
            stocks.push({ ticker: row[0], companyName: row[1] });
        })
            .on('end', () => resolve(stocks));
    });
}
//# sourceMappingURL=load-csv-data.js.map