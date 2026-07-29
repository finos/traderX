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
