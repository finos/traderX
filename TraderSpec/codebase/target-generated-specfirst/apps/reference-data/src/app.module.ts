import { Module } from '@nestjs/common';
import { StocksModule } from './stocks/stocks.module';
import HealthModule from './health/health.module';

@Module({
    imports: [StocksModule,HealthModule]
})
export class AppModule {}