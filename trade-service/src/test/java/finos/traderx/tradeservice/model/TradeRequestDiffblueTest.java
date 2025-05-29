package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class TradeRequestDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link TradeRequest}
   *   <li>{@link TradeRequest#setAccountId(int)}
   *   <li>{@link TradeRequest#setQuantity(Integer)}
   *   <li>{@link TradeRequest#setSecurity(String)}
   *   <li>{@link TradeRequest#setSide(TradeSide)}
   *   <li>{@link TradeRequest#getAccountId()}
   *   <li>{@link TradeRequest#getQuantity()}
   *   <li>{@link TradeRequest#getSecurity()}
   *   <li>{@link TradeRequest#getSide()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void TradeRequest.<init>()", "int TradeRequest.getAccountId()",
      "Integer TradeRequest.getQuantity()", "String TradeRequest.getSecurity()", "TradeSide TradeRequest.getSide()",
      "void TradeRequest.setAccountId(int)", "void TradeRequest.setQuantity(Integer)",
      "void TradeRequest.setSecurity(String)", "void TradeRequest.setSide(TradeSide)"})
  void testGettersAndSetters() {
    // Arrange and Act
    TradeRequest actualTradeRequest = new TradeRequest();
    actualTradeRequest.setAccountId(1);
    actualTradeRequest.setQuantity(1);
    actualTradeRequest.setSecurity("Security");
    actualTradeRequest.setSide(TradeSide.Buy);
    int actualAccountId = actualTradeRequest.getAccountId();
    Integer actualQuantity = actualTradeRequest.getQuantity();
    String actualSecurity = actualTradeRequest.getSecurity();
    TradeSide actualSide = actualTradeRequest.getSide();

    // Assert
    assertEquals("Security", actualSecurity);
    assertEquals(1, actualAccountId);
    assertEquals(1, actualQuantity.intValue());
    assertEquals(TradeSide.Buy, actualSide);
  }
}
