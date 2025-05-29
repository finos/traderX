package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {Security.class})
@ExtendWith(SpringExtension.class)
class SecurityDiffblueTest {
  @Autowired
  private Security security;

  /**
   * Test getters and setters.
   * <ul>
   *   <li>Then return Ticker is {@code null}.</li>
   * </ul>
   * <p>
   * Methods under test:
   * <ul>
   *   <li>{@link Security#Security()}
   *   <li>{@link Security#getTicker()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters; then return Ticker is 'null'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void Security.<init>()", "void Security.<init>(String, String)", "String Security.getTicker()"})
  void testGettersAndSetters_thenReturnTickerIsNull() {
    // Arrange, Act and Assert
    assertNull((new Security()).getTicker());
  }

  /**
   * Test getters and setters.
   * <ul>
   *   <li>When {@code Ticker}.</li>
   *   <li>Then return {@code Ticker}.</li>
   * </ul>
   * <p>
   * Methods under test:
   * <ul>
   *   <li>{@link Security#Security(String, String)}
   *   <li>{@link Security#getTicker()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters; when 'Ticker'; then return 'Ticker'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void Security.<init>()", "void Security.<init>(String, String)", "String Security.getTicker()"})
  void testGettersAndSetters_whenTicker_thenReturnTicker() {
    // Arrange, Act and Assert
    assertEquals("Ticker", (new Security("Ticker", "Company Name")).getTicker());
  }

  /**
   * Test {@link Security#getcompanyName()}.
   * <p>
   * Method under test: {@link Security#getcompanyName()}
   */
  @Test
  @DisplayName("Test getcompanyName()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"String Security.getcompanyName()"})
  void testGetcompanyName() {
    // Arrange, Act and Assert
    assertNull(security.getcompanyName());
  }
}
