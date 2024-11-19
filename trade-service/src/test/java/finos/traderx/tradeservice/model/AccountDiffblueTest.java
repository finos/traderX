package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {Account.class})
@ExtendWith(SpringExtension.class)
class AccountDiffblueTest {
  @Autowired
  private Account account;

  /**
   * Test {@link Account#Account()}.
   * <ul>
   *   <li>Then return getid is {@code null}.</li>
   * </ul>
   * <p>
   * Method under test: {@link Account#Account()}
   */
  @Test
  @DisplayName("Test new Account(); then return getid is 'null'")
  void testNewAccount_thenReturnGetidIsNull() {
    // Arrange, Act and Assert
    assertNull((new Account()).getid());
  }

  /**
   * Test {@link Account#Account(Integer, String)}.
   * <ul>
   *   <li>When one.</li>
   *   <li>Then return getid intValue is one.</li>
   * </ul>
   * <p>
   * Method under test: {@link Account#Account(Integer, String)}
   */
  @Test
  @DisplayName("Test new Account(Integer, String); when one; then return getid intValue is one")
  void testNewAccount_whenOne_thenReturnGetidIntValueIsOne() {
    // Arrange, Act and Assert
    assertEquals(1, (new Account(1, "Display Name")).getid().intValue());
  }

  /**
   * Test {@link Account#getid()}.
   * <p>
   * Method under test: {@link Account#getid()}
   */
  @Test
  @DisplayName("Test getid()")
  void testGetid() {
    // Arrange, Act and Assert
    assertNull(account.getid());
  }

  /**
   * Test {@link Account#getdisplayName()}.
   * <p>
   * Method under test: {@link Account#getdisplayName()}
   */
  @Test
  @DisplayName("Test getdisplayName()")
  void testGetdisplayName() {
    // Arrange, Act and Assert
    assertNull(account.getdisplayName());
  }
}
