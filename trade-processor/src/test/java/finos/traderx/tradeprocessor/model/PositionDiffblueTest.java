package finos.traderx.tradeprocessor.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PositionDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link Position}
   *   <li>{@link Position#setAccountId(Integer)}
   *   <li>{@link Position#setQuantity(Integer)}
   *   <li>{@link Position#setSecurity(String)}
   *   <li>{@link Position#setUpdated(Date)}
   *   <li>{@link Position#getAccountId()}
   *   <li>{@link Position#getQuantity()}
   *   <li>{@link Position#getSecurity()}
   *   <li>{@link Position#getUpdated()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  void testGettersAndSetters() {
    // Arrange and Act
    Position actualPosition = new Position();
    actualPosition.setAccountId(1);
    actualPosition.setQuantity(1);
    actualPosition.setSecurity("Security");
    Date u = Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant());
    actualPosition.setUpdated(u);
    Integer actualAccountId = actualPosition.getAccountId();
    Integer actualQuantity = actualPosition.getQuantity();
    String actualSecurity = actualPosition.getSecurity();
    Date actualUpdated = actualPosition.getUpdated();

    // Assert that nothing has changed
    assertEquals("Security", actualSecurity);
    assertEquals(1, actualAccountId.intValue());
    assertEquals(1, actualQuantity.intValue());
    assertSame(u, actualUpdated);
  }
}
