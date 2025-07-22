package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks enum values for TradeState.
 * This is the best approach for an enum.
 */
class TradeStateTest {
    @Test
    void testEnumValues() {
        assertEquals(TradeState.New, TradeState.valueOf("New"));
        assertEquals(TradeState.Processing, TradeState.valueOf("Processing"));
        assertEquals(TradeState.Settled, TradeState.valueOf("Settled"));
        assertEquals(TradeState.Cancelled, TradeState.valueOf("Cancelled"));
    }
}
