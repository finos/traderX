package finos.traderx.tradeprocessor;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import com.diffblue.cover.annotations.MethodsUnderTest;
import finos.traderx.messaging.Subscriber;
import finos.traderx.tradeprocessor.model.TradeOrder;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class PubSubConfigDiffblueTest {
  /**
   * Test {@link PubSubConfig#tradeFeedHandler()}.
   * <p>
   * Method under test: {@link PubSubConfig#tradeFeedHandler()}
   */
  @Test
  @DisplayName("Test tradeFeedHandler()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"Subscriber PubSubConfig.tradeFeedHandler()"})
  void testTradeFeedHandler() {
    // Arrange and Act
    Subscriber<TradeOrder> actualTradeFeedHandlerResult = (new PubSubConfig()).tradeFeedHandler();

    // Assert
    assertTrue(actualTradeFeedHandlerResult instanceof TradeFeedHandler);
    assertFalse(actualTradeFeedHandlerResult.isConnected());
  }
}
