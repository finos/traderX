package finos.traderx.positionservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import com.diffblue.cover.annotations.MethodsUnderTest;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
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
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void Position.<init>()", "Integer Position.getAccountId()", "Integer Position.getQuantity()",
      "String Position.getSecurity()", "Date Position.getUpdated()", "void Position.setAccountId(Integer)",
      "void Position.setQuantity(Integer)", "void Position.setSecurity(String)", "void Position.setUpdated(Date)"})
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

    // Assert
    assertEquals("Security", actualSecurity);
    assertEquals(1, actualAccountId.intValue());
    assertEquals(1, actualQuantity.intValue());
    assertSame(u, actualUpdated);
  }
}
