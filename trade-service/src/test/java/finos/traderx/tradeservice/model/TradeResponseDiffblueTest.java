package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

class TradeResponseDiffblueTest {
  /**
   * Test {@link TradeResponse#success(String)}.
   * <p>
   * Method under test: {@link TradeResponse#success(String)}
   */
  @Test
  @DisplayName("Test success(String)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"TradeResponse TradeResponse.success(String)"})
  void testSuccess() {
    // Arrange and Act
    TradeResponse actualSuccessResult = TradeResponse.success("42");

    // Assert
    assertEquals("42", actualSuccessResult.getId());
    assertNull(actualSuccessResult.getErrorMessage());
    assertTrue(actualSuccessResult.isSuccess());
  }

  /**
   * Test {@link TradeResponse#error(String)}.
   * <p>
   * Method under test: {@link TradeResponse#error(String)}
   */
  @Test
  @DisplayName("Test error(String)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"TradeResponse TradeResponse.error(String)"})
  void testError() {
    // Arrange and Act
    TradeResponse actualErrorResult = TradeResponse.error("Not all who wander are lost");

    // Assert
    assertEquals("Not all who wander are lost", actualErrorResult.getErrorMessage());
    assertNull(actualErrorResult.getId());
    assertFalse(actualErrorResult.isSuccess());
  }

  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>default or parameterless constructor of {@link TradeResponse}
   *   <li>{@link TradeResponse#setErrorMessage(String)}
   *   <li>{@link TradeResponse#setId(String)}
   *   <li>{@link TradeResponse#setSuccess(boolean)}
   *   <li>{@link TradeResponse#getErrorMessage()}
   *   <li>{@link TradeResponse#getId()}
   *   <li>{@link TradeResponse#isSuccess()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void TradeResponse.<init>()", "String TradeResponse.getErrorMessage()",
      "String TradeResponse.getId()", "boolean TradeResponse.isSuccess()", "void TradeResponse.setErrorMessage(String)",
      "void TradeResponse.setId(String)", "void TradeResponse.setSuccess(boolean)"})
  void testGettersAndSetters() {
    // Arrange and Act
    TradeResponse actualTradeResponse = new TradeResponse();
    actualTradeResponse.setErrorMessage("An error occurred");
    actualTradeResponse.setId("42");
    actualTradeResponse.setSuccess(true);
    String actualErrorMessage = actualTradeResponse.getErrorMessage();
    String actualId = actualTradeResponse.getId();

    // Assert
    assertEquals("42", actualId);
    assertEquals("An error occurred", actualErrorMessage);
    assertTrue(actualTradeResponse.isSuccess());
  }
}
