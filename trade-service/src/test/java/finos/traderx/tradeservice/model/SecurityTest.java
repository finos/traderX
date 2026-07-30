package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the basic constructor and getters of Security.
 * This is the best approach for a POJO/data class.
 */
class SecurityTest {
    @Test
    void testConstructorAndGetters() {
        Security sec = new Security("AAPL", "Apple Inc.");
        assertEquals("AAPL", sec.getTicker());
        assertEquals("Apple Inc.", sec.getcompanyName());
    }
    @Test
    void testDefaultConstructor() {
        Security sec = new Security();
        assertNull(sec.getTicker());
        assertNull(sec.getcompanyName());
    }
}
