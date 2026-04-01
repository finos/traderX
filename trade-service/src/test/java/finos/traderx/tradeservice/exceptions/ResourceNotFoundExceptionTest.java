package finos.traderx.tradeservice.exceptions;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the message constructor of ResourceNotFoundException.
 * This is the best approach for a custom exception class.
 */
class ResourceNotFoundExceptionTest {
    @Test
    void testMessage() {
        ResourceNotFoundException ex = new ResourceNotFoundException("Not found");
        assertEquals("Not found", ex.getMessage());
    }
}
