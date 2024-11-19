package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PubSubExceptionDiffblueTest {
  /**
   * Test {@link PubSubException#PubSubException(String)}.
   * <ul>
   *   <li>When {@code Str}.</li>
   *   <li>Then return Cause is {@code null}.</li>
   * </ul>
   * <p>
   * Method under test: {@link PubSubException#PubSubException(String)}
   */
  @Test
  @DisplayName("Test new PubSubException(String); when 'Str'; then return Cause is 'null'")
  void testNewPubSubException_whenStr_thenReturnCauseIsNull() {
    // Arrange and Act
    PubSubException actualPubSubException = new PubSubException("Str");

    // Assert
    assertEquals("Str", actualPubSubException.getMessage());
    assertNull(actualPubSubException.getCause());
    assertEquals(0, actualPubSubException.getSuppressed().length);
  }

  /**
   * Test {@link PubSubException#PubSubException(String, Throwable)}.
   * <ul>
   *   <li>When {@code Str}.</li>
   *   <li>Then return Message is {@code Str}.</li>
   * </ul>
   * <p>
   * Method under test: {@link PubSubException#PubSubException(String, Throwable)}
   */
  @Test
  @DisplayName("Test new PubSubException(String, Throwable); when 'Str'; then return Message is 'Str'")
  void testNewPubSubException_whenStr_thenReturnMessageIsStr() {
    // Arrange
    Throwable t = new Throwable();

    // Act
    PubSubException actualPubSubException = new PubSubException("Str", t);

    // Assert
    assertEquals("Str", actualPubSubException.getMessage());
    assertEquals(0, actualPubSubException.getSuppressed().length);
    assertSame(t, actualPubSubException.getCause());
  }

  /**
   * Test {@link PubSubException#PubSubException(Throwable)}.
   * <ul>
   *   <li>When {@link Throwable#Throwable()}.</li>
   *   <li>Then return Message is {@code java.lang.Throwable}.</li>
   * </ul>
   * <p>
   * Method under test: {@link PubSubException#PubSubException(Throwable)}
   */
  @Test
  @DisplayName("Test new PubSubException(Throwable); when Throwable(); then return Message is 'java.lang.Throwable'")
  void testNewPubSubException_whenThrowable_thenReturnMessageIsJavaLangThrowable() {
    // Arrange
    Throwable t = new Throwable();

    // Act
    PubSubException actualPubSubException = new PubSubException(t);

    // Assert
    assertEquals("java.lang.Throwable", actualPubSubException.getMessage());
    assertEquals(0, actualPubSubException.getSuppressed().length);
    assertSame(t, actualPubSubException.getCause());
  }
}
