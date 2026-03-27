import { Controller, Get, NotFoundException, Param } from '@nestjs/common';
import { Stock } from './stock.model';
import { StocksService } from './stocks.service';

@Controller('stocks')
export class StocksController {
  constructor(private readonly stocksService: StocksService) {}

  @Get()
  async findAll(): Promise<Stock[]> {
    return this.stocksService.findAll();
  }

  @Get(':ticker')
  async findByTicker(@Param('ticker') ticker: string): Promise<Stock> {
    const stock = await this.stocksService.findByTicker(ticker);
    if (!stock) {
      throw new NotFoundException(`Stock ticker "${ticker}" not found.`);
    }
    return stock;
  }
}
