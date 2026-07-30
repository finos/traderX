package finos.traderx.tradeservice;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import io.swagger.v3.oas.models.OpenAPI;

/**
 * This test checks that the OpenAPI bean is created and contains expected info.
 * We use ReflectionTestUtils to set the port value, as Spring injection is not available in a plain unit test.
 * This is the best approach for a simple config class.
 */
class OpenApiConfigTest {
    @Test
    void configReturnsOpenAPI() {
        OpenApiConfig config = new OpenApiConfig();
        ReflectionTestUtils.setField(config, "port", 1234);
        OpenAPI openAPI = config.config();
        assertNotNull(openAPI);
        assertNotNull(openAPI.getInfo());
        assertEquals("FINOS TraderX Trading Service", openAPI.getInfo().getTitle());
    }
}
