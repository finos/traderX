package finos.traderx.tradeprocessor;

import static org.junit.jupiter.api.Assertions.assertFalse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TradeFeedHandlerDiffblueTest {
  /**
   * Test new {@link TradeFeedHandler} (default constructor).
   * <p>
   * Method under test: default or parameterless constructor of
   * {@link TradeFeedHandler}
   */
  @Test
  @DisplayName("Test new TradeFeedHandler (default constructor)")
  void testNewTradeFeedHandler() {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange, Act and Assert
    assertFalse((new TradeFeedHandler()).isConnected());
  }
}
