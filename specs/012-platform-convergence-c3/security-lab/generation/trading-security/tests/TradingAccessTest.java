package __PACKAGE__.security;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class TradingAccessTest {
  @Test void rolesAndAccountsRemainSeparate() {
    var grants=TradingAccess.parse("reader=read-only:22214\noperator=operator:\ntrader=trader:44044\n");
    assertEquals("read-only",grants.get("reader").role());
    assertTrue(grants.get("operator").accounts().isEmpty());
    assertFalse(grants.get("reader").accounts().contains(44044));
  }
  @Test void malformedOrAmbiguousGrantsFailClosed() {
    for(String text:new String[]{"", "a=admin:22214", "a=trader:0", "a=trader:1,1", "a=trader:1\na=operator:", "a=trader:1,", "a b=trader:1", "a=trader:2147483648"})
      assertThrows(IllegalArgumentException.class,()->TradingAccess.parse(text));
  }
}
