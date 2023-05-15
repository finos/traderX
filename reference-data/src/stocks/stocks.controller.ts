import { Controller, Get, NotFoundException, Param, Query } from '@nestjs/common';
import { StocksService } from './stocks.service';
import { Stock } from './interfaces/stock.interface';
import { ApiParam } from '@nestjs/swagger';


@Controller('stocks')
export class StocksController {
    constructor(private stocksService: StocksService) { }

    @Get()
    async findAll(): Promise<Stock[]> {
        const list=await this.stocksService.findAll();
        return list;
    }

    @Get( ':ticker')
    @ApiParam ({"name":"ticker"})
    async findByTicker(@Param("ticker") ticker): Promise<Stock> {
        const stock = await this.stocksService.findByTicker(ticker);
        if (stock === undefined) {
            throw new NotFoundException(
                `Stock ticker "${ticker}" not found.`
            );
        }
        return stock;
    }
}