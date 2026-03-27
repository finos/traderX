import { Controller, Get } from '@nestjs/common';
import { HealthCheckService, HealthCheck } from '@nestjs/terminus';

@Controller('health')
class HealthController {
    constructor(private health: HealthCheckService) {}

    @Get()
    @HealthCheck()
    check() {
        return this.health.check([]);
    }
}
export default HealthController;