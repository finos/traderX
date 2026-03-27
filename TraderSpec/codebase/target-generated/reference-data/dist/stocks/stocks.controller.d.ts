import { Stock } from './stock.model';
import { StocksService } from './stocks.service';
export declare class StocksController {
    private readonly stocksService;
    constructor(stocksService: StocksService);
    findAll(): Promise<Stock[]>;
    findByTicker(ticker: string): Promise<Stock>;
}
