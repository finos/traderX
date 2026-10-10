package finos.traderx.tradeservice.model;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the basic constructor and getters of Account.
 * This is the best approach for a POJO/data class.
 */
class AccountTest {
    @Test
    void testConstructorAndGetters() {
        Account acc = new Account(1, "Test Account");
        assertEquals(1, acc.getid());
        assertEquals("Test Account", acc.getdisplayName());
    }
    @Test
    void testDefaultConstructor() {
        Account acc = new Account();
        assertNull(acc.getid());
        assertNull(acc.getdisplayName());
    }
}
