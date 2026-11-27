package __PACKAGE__.security;

import __PACKAGE__.model.OrderRecord;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.access.AccessDeniedException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class OrderExecutionDispatchTest {
  OrderRecord order() {var order=new OrderRecord();order.setOrderId("order-19");return order;}
  @Test void reusesPendingIdAndTreatsLostResponseAsCommittedOnlyWithReceipt() throws Exception {
    var jdbc=mock(JdbcTemplate.class);var authority=mock(AcceptedOrderAuthority.class);UUID pending=UUID.randomUUID();
    when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(),eq("order-19"))).thenReturn(List.of(pending));
    when(jdbc.queryForObject(anyString(),eq(Long.class),eq(pending),eq(pending.toString()))).thenReturn(1L);
    var sent=new AtomicReference<UUID>();
    var execution=new MatcherExecution(jdbc,authority,()->"service-token",(id,token)->{sent.set(id);assertEquals("service-token",token);throw new IOException("response lost");});
    assertTrue(execution.dispatch(order(),6,new BigDecimal("99")));assertEquals(pending,sent.get());
    verify(jdbc,never()).queryForObject(eq("SELECT lab_execution.reserve(?,?,?,?)"),eq(UUID.class),any(),any(),any(),any());
    verify(authority).requireEligible(any());
  }
  @Test void networkSuccessWithoutDurableReceiptDoesNotCountAsFill() {
    var jdbc=mock(JdbcTemplate.class);var authority=mock(AcceptedOrderAuthority.class);UUID pending=UUID.randomUUID();
    when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(),eq("order-19"))).thenReturn(List.of(pending));
    when(jdbc.queryForObject(anyString(),eq(Long.class),eq(pending),eq(pending.toString()))).thenReturn(0L);
    var execution=new MatcherExecution(jdbc,authority,()->"token",(id,token)->{});
    assertFalse(execution.dispatch(order(),6,new BigDecimal("99")));
  }
  @Test void newReservationCommitsBeforeTokenAcquisitionOrSend() {
    var jdbc=mock(JdbcTemplate.class);var authority=mock(AcceptedOrderAuthority.class);
    var id=new AtomicReference<UUID>();var sent=new AtomicReference<UUID>();
    when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(),eq("order-19"))).thenReturn(List.of());
    when(jdbc.queryForObject(eq("SELECT lab_execution.reserve(?,?,?,?)"),eq(UUID.class),any(UUID.class),eq("order-19"),eq(6),eq(new BigDecimal("99"))))
      .thenAnswer(call->{id.set(call.getArgument(2));return id.get();});
    when(jdbc.queryForObject(anyString(),eq(Long.class),any(UUID.class),anyString())).thenReturn(1L);
    var execution=new MatcherExecution(jdbc,authority,()->{assertNotNull(id.get());return "token";},(value,token)->sent.set(value));
    assertTrue(execution.dispatch(order(),6,new BigDecimal("99")));assertEquals(id.get(),sent.get());
  }
  @Test void revokedAuthorityNeverTouchesLedgerTokenOrNetwork() {
    var jdbc=mock(JdbcTemplate.class);var authority=mock(AcceptedOrderAuthority.class);
    doThrow(new AccessDeniedException("revoked")).when(authority).requireEligible(any());
    var execution=new MatcherExecution(jdbc,authority,()->{fail("token");return "";},(id,token)->fail("send"));
    assertThrows(AccessDeniedException.class,()->execution.dispatch(order(),1,BigDecimal.ONE));verifyNoInteractions(jdbc);
  }
  @Test void unavailableTokenLeavesPendingExecutionForRetry() {
    var jdbc=mock(JdbcTemplate.class);UUID pending=UUID.randomUUID();
    when(jdbc.query(anyString(),org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(),eq("order-19"))).thenReturn(List.of(pending));
    when(jdbc.queryForObject(anyString(),eq(Long.class),eq(pending),eq(pending.toString()))).thenReturn(0L);
    var execution=new MatcherExecution(jdbc,mock(AcceptedOrderAuthority.class),()->{throw new IOException();},(id,token)->fail("send"));
    assertFalse(execution.dispatch(order(),1,BigDecimal.ONE));
  }
  @Test void requiresHttpsAndFixedExecutionPath() {
    var jdbc=mock(JdbcTemplate.class);var authority=mock(AcceptedOrderAuthority.class);
    for(String endpoint:List.of("http://processor/internal/executions/","https://processor/other/","https://user@processor/internal/executions/","https://processor/internal/executions/?x=1"))
      assertThrows(IllegalArgumentException.class,()->new MatcherExecution(jdbc,authority,endpoint,"https://id/token","matcher","/secret"));
  }
  @Test void cancellationBindsAccountAndNeverWritesOrderDirectly() {
    var jdbc=mock(JdbcTemplate.class);when(jdbc.queryForObject("SELECT lab_execution.cancel_order(?,?)",String.class,"order-19",22214)).thenReturn("order-19");
    new MatcherExecution(jdbc,mock(AcceptedOrderAuthority.class),()->"",(id,token)->{}).cancel("order-19",22214);
    verify(jdbc).queryForObject("SELECT lab_execution.cancel_order(?,?)",String.class,"order-19",22214);verifyNoMoreInteractions(jdbc);
  }
}
