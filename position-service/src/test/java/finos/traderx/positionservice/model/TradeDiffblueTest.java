package finos.traderx.positionservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class TradeDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link Trade}
   *   <li>{@link Trade#setAccountId(Integer)}
   *   <li>{@link Trade#setCreated(Date)}
   *   <li>{@link Trade#setId(String)}
   *   <li>{@link Trade#setQuantity(Integer)}
   *   <li>{@link Trade#setSecurity(String)}
   *   <li>{@link Trade#setSide(String)}
   *   <li>{@link Trade#setState(String)}
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
    // Arrange and Act
    Trade actualTrade = new Trade();
    actualTrade.setAccountId(1);
    Date u = Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant());
    actualTrade.setCreated(u);
    actualTrade.setId("42");
    actualTrade.setQuantity(1);
    actualTrade.setSecurity("Security");
    actualTrade.setSide("Side");
    actualTrade.setState("MD");
    Date u2 = Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant());
    actualTrade.setUpdated(u2);
    Integer actualAccountId = actualTrade.getAccountId();
    Date actualCreated = actualTrade.getCreated();
    String actualId = actualTrade.getId();
    Integer actualQuantity = actualTrade.getQuantity();
    String actualSecurity = actualTrade.getSecurity();
    String actualSide = actualTrade.getSide();
    String actualState = actualTrade.getState();
    Date actualUpdated = actualTrade.getUpdated();

    // Assert that nothing has changed
    assertEquals("42", actualId);
    assertEquals("MD", actualState);
    assertEquals("Security", actualSecurity);
    assertEquals("Side", actualSide);
    assertEquals(1, actualAccountId.intValue());
    assertEquals(1, actualQuantity.intValue());
    assertSame(u, actualCreated);
    assertSame(u2, actualUpdated);
  }
}
