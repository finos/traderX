package finos.traderx.messaging.socketio;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import finos.traderx.messaging.PubSubException;
import finos.traderx.tradeprocessor.TradeFeedHandler;
import io.socket.client.IO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class SocketIOJSONSubscriberDiffblueTest {
  /**
   * Test {@link SocketIOJSONSubscriber#getIOOptions()}.
   * <p>
   * Method under test: {@link SocketIOJSONSubscriber#getIOOptions()}
   */
  @Test
  @DisplayName("Test getIOOptions()")
  void testGetIOOptions() {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange and Act
    IO.Options actualIOOptions = (new TradeFeedHandler()).getIOOptions();

    // Assert
    assertNull(actualIOOptions.transports);
    assertNull(actualIOOptions.decoder);
    assertNull(actualIOOptions.encoder);
    assertNull(actualIOOptions.host);
    assertNull(actualIOOptions.query);
    assertNull(actualIOOptions.hostname);
    assertNull(actualIOOptions.path);
    assertNull(actualIOOptions.timestampParam);
    assertNull(actualIOOptions.transportOptions);
    assertNull(actualIOOptions.auth);
    assertNull(actualIOOptions.extraHeaders);
    assertNull(actualIOOptions.callFactory);
    assertNull(actualIOOptions.webSocketFactory);
    assertEquals(-1, actualIOOptions.policyPort);
    assertEquals(-1, actualIOOptions.port);
    assertEquals(0, actualIOOptions.reconnectionAttempts);
    assertEquals(0.0d, actualIOOptions.randomizationFactor);
    assertEquals(0L, actualIOOptions.reconnectionDelay);
    assertEquals(0L, actualIOOptions.reconnectionDelayMax);
    assertEquals(20000L, actualIOOptions.timeout);
    assertFalse(actualIOOptions.forceNew);
    assertFalse(actualIOOptions.rememberUpgrade);
    assertFalse(actualIOOptions.secure);
    assertFalse(actualIOOptions.timestampRequests);
    assertTrue(actualIOOptions.multiplex);
    assertTrue(actualIOOptions.reconnection);
    assertTrue(actualIOOptions.upgrade);
  }

  /**
   * Test {@link SocketIOJSONSubscriber#isConnected()}.
   * <p>
   * Method under test: {@link SocketIOJSONSubscriber#isConnected()}
   */
  @Test
  @DisplayName("Test isConnected()")
  void testIsConnected() {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange, Act and Assert
    assertFalse((new TradeFeedHandler()).isConnected());
  }

  /**
   * Test {@link SocketIOJSONSubscriber#afterPropertiesSet()}.
   * <ul>
   *   <li>Given {@link TradeFeedHandler} (default constructor) SocketAddress is
   * {@code 42 Main St}.</li>
   * </ul>
   * <p>
   * Method under test: {@link SocketIOJSONSubscriber#afterPropertiesSet()}
   */
  @Test
  @DisplayName("Test afterPropertiesSet(); given TradeFeedHandler (default constructor) SocketAddress is '42 Main St'")
  void testAfterPropertiesSet_givenTradeFeedHandlerSocketAddressIs42MainSt() throws Exception {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange
    TradeFeedHandler tradeFeedHandler = new TradeFeedHandler();
    tradeFeedHandler.setSocketAddress("42 Main St");

    // Act and Assert
    assertThrows(PubSubException.class, () -> tradeFeedHandler.afterPropertiesSet());
  }

  /**
   * Test {@link SocketIOJSONSubscriber#afterPropertiesSet()}.
   * <ul>
   *   <li>Given {@link TradeFeedHandler} (default constructor) SocketAddress is
   * {@code Addr}.</li>
   * </ul>
   * <p>
   * Method under test: {@link SocketIOJSONSubscriber#afterPropertiesSet()}
   */
  @Test
  @DisplayName("Test afterPropertiesSet(); given TradeFeedHandler (default constructor) SocketAddress is 'Addr'")
  void testAfterPropertiesSet_givenTradeFeedHandlerSocketAddressIsAddr() throws Exception {
    //   Diffblue Cover was unable to create a Spring-specific test for this Spring method.
    //   Run dcover create --keep-partial-tests to gain insights into why
    //   a non-Spring test was created.

    // Arrange
    TradeFeedHandler tradeFeedHandler = new TradeFeedHandler();
    tradeFeedHandler.setSocketAddress("Addr");

    // Act and Assert
    assertThrows(PubSubException.class, () -> tradeFeedHandler.afterPropertiesSet());
  }
}
