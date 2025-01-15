package finos.traderx.tradeprocessor.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {Trade.class})
@ExtendWith(SpringExtension.class)
class TradeDiffblueTest {
  @Autowired
  private Trade trade;

  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>{@link Trade#setAccountId(Integer)}
   *   <li>{@link Trade#setCreated(Date)}
   *   <li>{@link Trade#setId(String)}
   *   <li>{@link Trade#setQuantity(Integer)}
   *   <li>{@link Trade#setSecurity(String)}
   *   <li>{@link Trade#setSide(TradeSide)}
   *   <li>{@link Trade#setState(TradeState)}
   *   <li>{@link Trade#setUpdated(Date)}
   *   <li>{@link Trade#getAccountId()}
   *   <li>{@link Trade#getCreated()}
   *   <li>{@link Trade#getId()}
   *   <li>{@link Trade#getQuantity()}
   *   <li>{@link Trade#getSecurity()}
   *   <li>{@link Trade#getSide()}
   *   <li>{@link Trade#getState()}
   *   <li>{@link Trade#getUpdated()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  void testGettersAndSetters() {
    // Arrange
    Trade trade = new Trade();

    // Act
    trade.setAccountId(1);
    Date u = Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant());
    trade.setCreated(u);
    trade.setId("42");
    trade.setQuantity(1);
    trade.setSecurity("Security");
    trade.setSide(TradeSide.Buy);
    trade.setState(TradeState.New);
    Date u2 = Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant());
    trade.setUpdated(u2);
    Integer actualAccountId = trade.getAccountId();
    Date actualCreated = trade.getCreated();
    String actualId = trade.getId();
    Integer actualQuantity = trade.getQuantity();
    String actualSecurity = trade.getSecurity();
    TradeSide actualSide = trade.getSide();
    TradeState actualState = trade.getState();
    Date actualUpdated = trade.getUpdated();

    // Assert
    assertEquals("42", actualId);
    assertEquals("Security", actualSecurity);
    assertEquals(1, actualAccountId.intValue());
    assertEquals(1, actualQuantity.intValue());
    assertEquals(TradeSide.Buy, actualSide);
    assertEquals(TradeState.New, actualState);
    assertSame(u, actualCreated);
    assertSame(u2, actualUpdated);
  }

  /**
   * Test new {@link Trade} (default constructor).
   * <p>
   * Method under test: default or parameterless constructor of {@link Trade}
   */
  @Test
  @DisplayName("Test new Trade (default constructor)")
  void testNewTrade() {
    // Arrange and Act
    Trade actualTrade = new Trade();

    // Assert
    assertNull(actualTrade.getSide());
    assertNull(actualTrade.getAccountId());
    assertNull(actualTrade.getQuantity());
    assertNull(actualTrade.getId());
    assertNull(actualTrade.getSecurity());
    assertNull(actualTrade.getCreated());
    assertNull(actualTrade.getUpdated());
    assertEquals(TradeState.New, actualTrade.getState());
  }
}
