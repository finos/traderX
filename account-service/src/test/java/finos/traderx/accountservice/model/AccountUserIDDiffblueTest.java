package finos.traderx.accountservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class AccountUserIDDiffblueTest {
  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link AccountUserID}
   *   <li>{@link AccountUserID#setAccountId(Integer)}
   *   <li>{@link AccountUserID#setUsername(String)}
   *   <li>{@link AccountUserID#getAccountId()}
   *   <li>{@link AccountUserID#getUsername()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void AccountUserID.<init>()", "Integer AccountUserID.getAccountId()",
      "String AccountUserID.getUsername()", "void AccountUserID.setAccountId(Integer)",
      "void AccountUserID.setUsername(String)"})
  void testGettersAndSetters() {
    // Arrange and Act
    AccountUserID actualAccountUserID = new AccountUserID();
    actualAccountUserID.setAccountId(1);
    actualAccountUserID.setUsername("janedoe");
    Integer actualAccountId = actualAccountUserID.getAccountId();

    // Assert
    assertEquals("janedoe", actualAccountUserID.getUsername());
    assertEquals(1, actualAccountId.intValue());
  }
}
