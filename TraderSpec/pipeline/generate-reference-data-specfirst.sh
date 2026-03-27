#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/reference-data-specfirst"
SOURCE_CSV="${ROOT}/templates/reference-data/s-and-p-500-companies.csv"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/src/health" \
  "${TARGET}/src/stocks" \
  "${TARGET}/src/data-loader" \
  "${TARGET}/data"

cat <<'EOF' > "${TARGET}/README.md"
# Reference-Data (Spec-First Generated)

This component is generated from TraderSpec component requirements, without hydrating source files from the root implementation.

## Run

```bash
npm install
npm run start
```

Default port: `18085` (override with `REFERENCE_DATA_SERVICE_PORT`).

## CORS (Baseline State Requirement)

- Default: allow all origins (`CORS_ALLOWED_ORIGINS=*`).
- Optional: comma-separated allowlist via `CORS_ALLOWED_ORIGINS`.

## Dataset

- Loads stock symbols from `data/s-and-p-500-companies.csv` (baseline parity dataset).
EOF

cat <<'EOF' > "${TARGET}/package.json"
{
  "name": "@traderspec/reference-data-specfirst",
  "version": "0.1.0",
  "private": true,
  "license": "Apache-2.0",
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:prod": "node dist/main.js"
  },
  "dependencies": {
    "@nestjs/common": "^11.0.12",
    "@nestjs/core": "^11.0.12",
    "@nestjs/platform-express": "^11.0.12",
    "csv-reader": "^1.0.12",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.2"
  },
  "devDependencies": {
    "@nestjs/cli": "^11.0.5",
    "@types/node": "^22.13.14",
    "ts-node": "^10.9.2",
    "typescript": "^5.8.2"
  }
}
EOF

cat <<'EOF' > "${TARGET}/tsconfig.json"
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "es2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": [
    "src/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
EOF

cat <<'EOF' > "${TARGET}/nest-cli.json"
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src"
}
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.0
info:
  title: TraderSpec Reference Data Service
  version: "1.0.0"
paths:
  /health:
    get:
      summary: Health check
      responses:
        "200":
          description: Service is healthy
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Health"
  /stocks:
    get:
      summary: List all stocks
      responses:
        "200":
          description: Stock list
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "#/components/schemas/Security"
  /stocks/{ticker}:
    get:
      summary: Find stock by ticker
      parameters:
      - name: ticker
        in: path
        required: true
        schema:
          type: string
      responses:
        "200":
          description: Stock found
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Security"
        "404":
          description: Not found
components:
  schemas:
    Security:
      type: object
      required:
      - ticker
      - companyName
      properties:
        ticker:
          type: string
          example: AAPL
        companyName:
          type: string
          example: Apple Inc.
    Health:
      type: object
      required:
      - status
      properties:
        status:
          type: string
          example: ok
EOF

cat <<'EOF' > "${TARGET}/src/main.ts"
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configuredOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? '*')
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  app.enableCors({
    origin: configuredOrigins.includes('*') ? true : configuredOrigins,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['*'],
  });

  const port = Number(process.env.REFERENCE_DATA_SERVICE_PORT ?? 18085);
  await app.listen(port, '0.0.0.0');
  // Used by startup orchestration readiness checks.
  // eslint-disable-next-line no-console
  console.log(`[ready] reference-data-specfirst listening on :${port}`);
}

bootstrap();
EOF

cat <<'EOF' > "${TARGET}/src/app.module.ts"
import { Module } from '@nestjs/common';
import { HealthModule } from './health/health.module';
import { StocksModule } from './stocks/stocks.module';

@Module({
  imports: [StocksModule, HealthModule],
})
export class AppModule {}
EOF

if [[ -f "${SOURCE_CSV}" ]]; then
  cp "${SOURCE_CSV}" "${TARGET}/data/s-and-p-500-companies.csv"
else
  cat <<'EOF' > "${TARGET}/data/s-and-p-500-companies.csv"
Symbol,Security
AAPL,Apple Inc.
MSFT,Microsoft Corporation
AMZN,Amazon.com Inc.
GOOGL,Alphabet Inc.
EOF
fi

cat <<'EOF' > "${TARGET}/src/data-loader/load-csv-data.ts"
import * as fs from 'fs';
const CsvReadableStream = require('csv-reader');
import { Stock } from '../stocks/stock.model';

export async function loadCsvData(): Promise<Stock[]> {
  return new Promise<Stock[]>((resolve) => {
    const stocks: Stock[] = [];
    let isHeaderRow = true;
    fs.createReadStream('./data/s-and-p-500-companies.csv', 'utf8')
      .pipe(new CsvReadableStream({ trim: true }))
      .on('data', (row: string[]) => {
        if (isHeaderRow) {
          isHeaderRow = false;
          return;
        }
        stocks.push({ ticker: row[0], companyName: row[1] });
      })
      .on('end', () => resolve(stocks));
  });
}
EOF

cat <<'EOF' > "${TARGET}/src/health/health.controller.ts"
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  health() {
    return { status: 'ok' };
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/health/health.module.ts"
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController],
})
export class HealthModule {}
EOF

cat <<'EOF' > "${TARGET}/src/stocks/stock.model.ts"
export interface Stock {
  ticker: string;
  companyName: string;
}
EOF

cat <<'EOF' > "${TARGET}/src/stocks/stocks.service.ts"
import { Injectable } from '@nestjs/common';
import { loadCsvData } from '../data-loader/load-csv-data';
import { Stock } from './stock.model';

@Injectable()
export class StocksService {
  private readonly stocks: Promise<Stock[]>;

  constructor() {
    this.stocks = loadCsvData();
  }

  async findAll(): Promise<Stock[]> {
    return this.stocks;
  }

  async findByTicker(ticker: string): Promise<Stock | undefined> {
    return (await this.stocks).find((stock) => stock.ticker === ticker);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/stocks/stocks.controller.ts"
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
EOF

cat <<'EOF' > "${TARGET}/src/stocks/stocks.module.ts"
import { Module } from '@nestjs/common';
import { StocksController } from './stocks.controller';
import { StocksService } from './stocks.service';

@Module({
  controllers: [StocksController],
  providers: [StocksService],
  exports: [StocksService],
})
export class StocksModule {}
EOF

echo "[done] regenerated ${TARGET}"
