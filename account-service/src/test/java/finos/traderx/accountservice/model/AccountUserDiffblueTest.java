package finos.traderx.accountservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AccountUserDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link AccountUser}
   *   <li>{@link AccountUser#setAccountId(Integer)}
   *   <li>{@link AccountUser#setUsername(String)}
   *   <li>{@link AccountUser#getAccountId()}
   *   <li>{@link AccountUser#getUsername()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  void testGettersAndSetters() {
    // Arrange and Act
    AccountUser actualAccountUser = new AccountUser();
    actualAccountUser.setAccountId(1);
    actualAccountUser.setUsername("janedoe");
    Integer actualAccountId = actualAccountUser.getAccountId();

    // Assert that nothing has changed
    assertEquals("janedoe", actualAccountUser.getUsername());
    assertEquals(1, actualAccountId.intValue());
  }
}
