package finos.traderx.positionservice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.SpecVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class OpenApiConfigDiffblueTest {
  /**
   * Test {@link OpenApiConfig#config()}.
   * <p>
   * Method under test: {@link OpenApiConfig#config()}
   */
  @Test
  @DisplayName("Test config()")
  void testConfig() {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange and Act
    OpenAPI actualConfigResult = (new OpenApiConfig()).config();

    // Assert
    assertEquals("3.0.1", actualConfigResult.getOpenapi());
    assertNull(actualConfigResult.getComponents());
    assertNull(actualConfigResult.getExternalDocs());
    assertNull(actualConfigResult.getPaths());
    assertNull(actualConfigResult.getJsonSchemaDialect());
    assertNull(actualConfigResult.getSecurity());
    assertNull(actualConfigResult.getTags());
    assertNull(actualConfigResult.getWebhooks());
    assertNull(actualConfigResult.getExtensions());
    assertEquals(2, actualConfigResult.getServers().size());
    assertEquals(SpecVersion.V30, actualConfigResult.getSpecVersion());
  }
}
