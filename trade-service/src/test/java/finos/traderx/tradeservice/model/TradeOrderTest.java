package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the constructor and getters of TradeOrder.
 * This is the best approach for a POJO/data class.
 */
class TradeOrderTest {
    @Test
    void testConstructorAndGetters() {
        TradeOrder order = new TradeOrder("id1", 2, "AAPL", TradeSide.Buy, 100);
        assertEquals("id1", order.getId());
        assertEquals(2, order.getAccountId());
        assertEquals("AAPL", order.getSecurity());
        assertEquals(TradeSide.Buy, order.getSide());
        assertEquals(100, order.getQuantity());
    }
    @Test
    void testDefaultConstructor() {
        TradeOrder order = new TradeOrder();
        assertNull(order.getId());
        assertNull(order.getSecurity());
        assertNull(order.getSide());
        assertNull(order.getAccountId());
        assertNull(order.getQuantity());
    }
}
