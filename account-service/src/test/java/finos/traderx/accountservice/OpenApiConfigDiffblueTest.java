package finos.traderx.accountservice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import com.diffblue.cover.annotations.MethodsUnderTest;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.SpecVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class OpenApiConfigDiffblueTest {
  /**
   * Test {@link OpenApiConfig#config()}.
   * <p>
   * Method under test: {@link OpenApiConfig#config()}
   */
  @Test
  @DisplayName("Test config()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"OpenAPI OpenApiConfig.config()"})
  void testConfig() {
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
