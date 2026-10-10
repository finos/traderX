package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the setters, getters, and static factory methods of TradeResponse.
 * This is the best approach for a POJO/data class.
 */
class TradeResponseTest {
    @Test
    void testSettersAndGetters() {
        TradeResponse resp = new TradeResponse();
        resp.setId("id123");
        resp.setSuccess(true);
        resp.setErrorMessage("none");
        assertEquals("id123", resp.getId());
        assertTrue(resp.isSuccess());
        assertEquals("none", resp.getErrorMessage());
    }
    @Test
    void testStaticSuccess() {
        TradeResponse resp = TradeResponse.success("id456");
        assertTrue(resp.isSuccess());
        assertEquals("id456", resp.getId());
    }
    @Test
    void testStaticError() {
        TradeResponse resp = TradeResponse.error("fail");
        assertFalse(resp.isSuccess());
        assertEquals("fail", resp.getErrorMessage());
    }
}
