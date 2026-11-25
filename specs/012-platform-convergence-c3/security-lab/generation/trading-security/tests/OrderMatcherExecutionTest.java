package __PACKAGE__.security;

import __PACKAGE__.repository.OrderRepository;
import __PACKAGE__.service.OrderMatcherService;
import __PACKAGE__.model.OrderRecord;
import __PACKAGE__.model.OrderStatus;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={
 "spring.datasource.url=jdbc:h2:mem:dispatch;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
 "spring.datasource.driverClassName=org.h2.Driver","spring.datasource.username=sa","spring.datasource.password=sa",
 "spring.jpa.database-platform=org.hibernate.dialect.H2Dialect","spring.jpa.hibernate.ddl-auto=create-drop",
 "order.matcher.seed-enabled=false","order.matcher.tick-ms=3600000","order.matcher.publisher=noop",
 "order.matcher.pricing-subscriber.enabled=false"
})
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
class OrderMatcherExecutionTest extends SecurityTestSupport {
 @Autowired OrderMatcherService matcher;
 @Autowired JdbcTemplate jdbc;
 @MockitoSpyBean OrderRepository repository;
 @MockitoBean MatcherExecution execution;
 String create() throws Exception {
   String body=mvc.perform(post("/orders").header("Authorization","Bearer "+token("trader")).contentType("application/json")
     .content("{\"accountId\":22214,\"security\":\"IBM\",\"side\":\"Buy\",\"quantity\":10,\"limitPrice\":100}"))
     .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
   return com.jayway.jsonpath.JsonPath.read(body,"$.orderId");
 }
 @Test void committedFillReloadsInsteadOfSavingASecondLocalFill() throws Exception {
   String id=create();clearInvocations(repository);
   when(execution.dispatch(argThat(o->id.equals(o.getOrderId())),eq(10),any())).thenAnswer(call->{
     jdbc.update("UPDATE order_book SET remaining_quantity=0,status='FILLED',last_fill_quantity=10 WHERE order_id=?",id);return true;
   });
   matcher.onPriceTick("IBM",new BigDecimal("99"));
   var after=repository.findById(id).orElseThrow();
   assertEquals(OrderStatus.FILLED,after.getStatus());assertEquals(0,after.getRemainingQuantity());assertEquals(10,after.getLastFillQuantity());
   verify(repository,never()).save(any(OrderRecord.class));
 }
 @Test void failedHandoffDoesNotChangeTheOrder() throws Exception {
   String id=create();var before=repository.findById(id).orElseThrow();clearInvocations(repository);
   when(execution.dispatch(any(),anyInt(),any())).thenReturn(false);
   matcher.onPriceTick("IBM",new BigDecimal("99"));
   var after=repository.findById(id).orElseThrow();assertEquals(before.getRemainingQuantity(),after.getRemainingQuantity());assertEquals(before.getUpdatedAt(),after.getUpdatedAt());
   verify(repository,never()).save(any(OrderRecord.class));
 }
 @Test void pendingExecutionRetriesWhenMarketIsOutsideLimit() throws Exception {
   String id=create();when(execution.hasPending(id)).thenReturn(true);
   matcher.onPriceTick("IBM",new BigDecimal("101"));
   verify(execution).dispatch(argThat(o->id.equals(o.getOrderId())),anyInt(),eq(new BigDecimal("101.000")));
 }
 @Test void cancellationReloadsDatabaseResultWithoutSavingStaleEntity() throws Exception {
   String id=create();clearInvocations(repository);
   doAnswer(call->{jdbc.update("UPDATE order_book SET remaining_quantity=0,status='FILLED',last_fill_quantity=10 WHERE order_id=?",id);return null;}).when(execution).cancel(id,22214);
   mvc.perform(post("/orders/"+id+"/cancel").header("Authorization","Bearer "+token("trader")))
     .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("FILLED"));
   verify(repository,never()).save(any(OrderRecord.class));assertEquals(10,repository.findById(id).orElseThrow().getLastFillQuantity());
 }
}
