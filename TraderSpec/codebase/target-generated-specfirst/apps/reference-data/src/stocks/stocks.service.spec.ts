import { Test, TestingModule } from '@nestjs/testing';
import { StocksService } from './stocks.service';

describe('StocksService', () => {
    let service: StocksService;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [StocksService]
        }).compile();

        service = module.get<StocksService>(StocksService);
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    it('gets all the stocks', async () => {
        const stocks = await service.findAll();
        expect(stocks.length).toBe(505);
        stocks.forEach((stock) => {
            expect(stock.ticker).toMatch(/^[A-Z.]+$/);
            expect(stock.companyName).toMatch(/^[A-Za-z0-9()-.!&' ]+$/);
        });
    });

    it('gets the stock with the ticker MMM', async () => {
        const stock = await service.findByTicker('MMM');
        expect(stock).toEqual({ ticker: 'MMM', companyName: '3M' });
    });

    it('gets the stock with the ticker MS', async () => {
        const stock = await service.findByTicker('MSFT');
        expect(stock).toEqual({ ticker: 'MSFT', companyName: 'Microsoft' });
    });

    it('returns undefined for the non existant ticker BADTICKER', async () => {
        const stock = await service.findByTicker('BADTICKER');
        expect(stock).toBeUndefined();
    });
});