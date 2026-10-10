package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks enum values for TradeSide.
 * This is the best approach for an enum.
 */
class TradeSideTest {
    @Test
    void testEnumValues() {
        assertEquals(TradeSide.Buy, TradeSide.valueOf("Buy"));
        assertEquals(TradeSide.Sell, TradeSide.valueOf("Sell"));
    }
}
