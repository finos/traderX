import { Stock } from './stock.model';
export declare class StocksService {
    private readonly stocks;
    constructor();
    findAll(): Promise<Stock[]>;
    findByTicker(ticker: string): Promise<Stock | undefined>;
}
