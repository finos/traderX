"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
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
    console.log(`[ready] reference-data-specfirst listening on :${port}`);
}
bootstrap();
//# sourceMappingURL=main.js.map