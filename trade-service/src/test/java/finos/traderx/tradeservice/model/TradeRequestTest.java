package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the setters and getters of TradeRequest.
 * This is the best approach for a POJO/data class.
 */
class TradeRequestTest {
    @Test
    void testSettersAndGetters() {
        TradeRequest req = new TradeRequest();
        req.setAccountId(5);
        req.setSecurity("IBM");
        req.setSide(TradeSide.Sell);
        req.setQuantity(10);
        assertEquals(5, req.getAccountId());
        assertEquals("IBM", req.getSecurity());
        assertEquals(TradeSide.Sell, req.getSide());
        assertEquals(10, req.getQuantity());
    }
}
