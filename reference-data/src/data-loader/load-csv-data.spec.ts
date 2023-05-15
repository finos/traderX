import { loadCsvData } from './load-csv-data';
import { Stock } from '../stocks/interfaces/stock.interface';

describe('loadCsvData', () => {
    describe('real stocks file tests', () => {
        let stocks: Stock[];

        beforeAll(async () => {
            stocks = await loadCsvData();
        });

        it('returns 505 stocks', async () => {
            expect(stocks.length).toBe(505);
        });

        it('returns 3M as the first stock', async () => {
            expect(stocks[0]).toEqual({ ticker: 'MMM', companyName: '3M' });
        });

        it('returns Zoetis as the last stock', async () => {
            expect(stocks[504]).toEqual({
                ticker: 'ZTS',
                companyName: 'Zoetis'
            });
        });
    });
});