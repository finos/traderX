import { Module } from '@nestjs/common';
import { StocksController as StocksController } from './stocks.controller';
import { StocksService } from './stocks.service';

@Module({
    providers: [StocksService],
    controllers: [StocksController]
})
export class StocksModule { }