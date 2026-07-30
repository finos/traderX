package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the constructors of PubSubException.
 * This is the best approach for a custom exception class.
 */
class PubSubExceptionTest {
    @Test
    void testMessageConstructor() {
        PubSubException ex = new PubSubException("error");
        assertEquals("error", ex.getMessage());
    }
    @Test
    void testMessageAndCauseConstructor() {
        Throwable t = new RuntimeException("cause");
        PubSubException ex = new PubSubException("error", t);
        assertEquals("error", ex.getMessage());
        assertEquals(t, ex.getCause());
    }
    @Test
    void testCauseConstructor() {
        Throwable t = new RuntimeException("cause");
        PubSubException ex = new PubSubException(t);
        assertEquals(t, ex.getCause());
    }
}
