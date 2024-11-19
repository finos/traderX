package finos.traderx.tradeprocessor.model;

import static org.junit.jupiter.api.Assertions.assertSame;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TradeBookingResultDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>{@link TradeBookingResult#TradeBookingResult(Trade, Position)}
   *   <li>{@link TradeBookingResult#getPosition()}
   *   <li>{@link TradeBookingResult#getTrade()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  void testGettersAndSetters() {
    // Arrange
    Trade t = new Trade();
    t.setAccountId(1);
    t.setCreated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    t.setId("42");
    t.setQuantity(1);
    t.setSecurity("Security");
    t.setSide(TradeSide.Buy);
    t.setState(TradeState.New);
    t.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position p = new Position();
    p.setAccountId(1);
    p.setQuantity(1);
    p.setSecurity("Security");
    p.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    // Act
    TradeBookingResult actualTradeBookingResult = new TradeBookingResult(t, p);
    Position actualPosition = actualTradeBookingResult.getPosition();

    // Assert
    assertSame(p, actualPosition);
    assertSame(t, actualTradeBookingResult.getTrade());
  }
}
