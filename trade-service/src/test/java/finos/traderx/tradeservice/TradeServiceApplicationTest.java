package finos.traderx.tradeservice;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * This test ensures the Spring context loads without errors.
 * This is the best approach for a Spring Boot main class, as it validates configuration and wiring.
 */
@SpringBootTest
class TradeServiceApplicationTest {
    @Test
    void contextLoads() {
        // If the context fails to load, this test will fail.
    }
}
