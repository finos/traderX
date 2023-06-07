import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

const port = parseInt(process.env.REFERENCE_DATA_SERVICE_PORT, 10) || 18085;
const hostname = process.env.REFERENCE_DATA_HOSTNAME || '0.0.0.0';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, { cors: true });

    const config = new DocumentBuilder()
        .setTitle('Reference Data Example')
        .setDescription('The Reference Data API description')
        .setVersion('1.0')
        .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api', app, document);

    await app.listen(port, hostname);
}
bootstrap();