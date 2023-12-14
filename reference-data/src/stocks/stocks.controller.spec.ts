import { Test, TestingModule } from '@nestjs/testing';
import { StocksController } from './stocks.controller';
import { StocksService } from './stocks.service';
import { NotFoundException } from '@nestjs/common';

describe('StocksController', () => {
    let controller: StocksController;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            controllers: [StocksController],
            providers: [StocksService]
        }).compile();

        controller = module.get<StocksController>(StocksController);
    });

    it('should be defined', () => {
        expect(controller).toBeDefined();
    });

    it('gets all the stocks', async () => {
        const stocks = await controller.findAll();
        expect(stocks.length).toBe(505);
    });

    it('gets the stock for ticker MSFT', async () => {
        const stock = await controller.findByTicker('MSFT');
        expect(stock).toEqual({ ticker: 'MSFT', companyName: 'Microsoft' });
    });

    it('throws an error for the non existant ticker BADTICKER', async () => {
        expect.assertions(1);
        try {
            await controller.findByTicker('BADTICKER');
        } catch (e) {
            expect(e).toEqual(
                new NotFoundException('Stock ticker "BADTICKER" not found.')
            );
        }
    });
});