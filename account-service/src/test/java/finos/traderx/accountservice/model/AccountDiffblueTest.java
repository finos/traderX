package finos.traderx.accountservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class AccountDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link Account}
   *   <li>{@link Account#setDisplayName(String)}
   *   <li>{@link Account#setId(int)}
   *   <li>{@link Account#getDisplayName()}
   *   <li>{@link Account#getId()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void Account.<init>()", "String Account.getDisplayName()", "int Account.getId()",
      "void Account.setDisplayName(String)", "void Account.setId(int)"})
  void testGettersAndSetters() {
    // Arrange and Act
    Account actualAccount = new Account();
    actualAccount.setDisplayName("Display Name");
    actualAccount.setId(1);
    String actualDisplayName = actualAccount.getDisplayName();

    // Assert
    assertEquals("Display Name", actualDisplayName);
    assertEquals(1, actualAccount.getId());
  }
}
