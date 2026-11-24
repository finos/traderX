package __PACKAGE__.security;

import __PACKAGE__.api.*;
import __PACKAGE__.controller.*;
import __PACKAGE__.model.OrderRecord;
import __PACKAGE__.service.OrderMatcherService;
import finos.traderx.messaging.Publisher;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ContextConfiguration(classes={OrderApiSecurityTest.Config.class,TradingSecurity.class,TradingAccess.class,OrderController.class,SystemController.class})
class OrderApiSecurityTest extends SecurityTestSupport {
  @Configuration @EnableWebMvc @EnableWebSecurity
  static class Config {
    @Bean OrderMatcherService service() { return mock(OrderMatcherService.class); }
    @Bean Publisher<OrderResponse> publisher() { return mock(Publisher.class); }
  }
  @Autowired OrderMatcherService service;
  @BeforeEach void resetService() { reset(service); }
  OrderResponse order(String id,int account) {
    var record=new OrderRecord();record.setOrderId(id);record.setAccountId(account);
    return OrderResponse.from(record,null);
  }
  @Test void unauthenticatedAndInvalidTokensNeverReachService() throws Exception {
    mvc.perform(get("/orders")).andExpect(status().isUnauthorized());
    for(String invalid:List.of("broken",token("trader",ISSUER,"wrong",300,KEYS),token("trader","https://wrong.test","traderx-api",300,KEYS),token("trader",ISSUER,"traderx-api",-1,KEYS),token("trader",ISSUER,"traderx-api",300,keys())))
      mvc.perform(get("/orders").header("Authorization","Bearer "+invalid)).andExpect(status().isUnauthorized());
    verifyNoInteractions(service);
  }
  @Test void listIsFilteredAndExplicitForeignFilterIsRejected() throws Exception {
    when(service.listOrders("open",null)).thenReturn(List.of(order("own",22214),order("foreign",44044)));
    mvc.perform(get("/orders").header("Authorization","Bearer "+token("reader"))).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].accountId").value(22214));
    clearInvocations(service);
    mvc.perform(get("/orders?accountId=44044").header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(service);
  }
  @Test void detailUsesStoredAccount() throws Exception {
    when(service.getOrder("foreign")).thenReturn(order("foreign",44044));
    mvc.perform(get("/orders/foreign").header("Authorization","Bearer "+token("trader"))).andExpect(status().isForbidden());
  }
  @Test void readerOperatorAndUnknownCannotCreateEvenWithSpoofedHeaders() throws Exception {
    for(String subject:List.of("reader","operator-account","unknown"))
      mvc.perform(post("/orders").header("Authorization","Bearer "+token(subject)).header("X-Role","trader").header("X-Account-Id","22214").contentType("application/json").content("{\"accountId\":22214}")).andExpect(status().isForbidden());
    verifyNoInteractions(service);
  }
  @Test void traderCannotCreateForAnotherAccount() throws Exception {
    mvc.perform(post("/orders").header("Authorization","Bearer "+token("trader")).contentType("application/json").content("{\"accountId\":44044}")).andExpect(status().isForbidden());
    verifyNoInteractions(service);
  }
  @Test void traderCreatesAndPublishesOwnOrder() throws Exception {
    var response=order("created",22214);when(service.createOrder(any())).thenReturn(response);
    mvc.perform(post("/orders").header("Authorization","Bearer "+token("trader")).contentType("application/json").content("{\"accountId\":22214}")).andExpect(status().isCreated());
    verify(service).createOrder(argThat(request->request.getAccountId()==22214));verify(service).publishOrderUpdate(response);
  }
  @Test void cancelCannotBeReassignedByCallerPayload() throws Exception {
    when(service.getOrder("foreign")).thenReturn(order("foreign",44044));
    mvc.perform(post("/orders/foreign/cancel?accountId=22214").header("Authorization","Bearer "+token("trader")).header("X-Account-Id","22214").contentType("application/json").content("{\"accountId\":22214}")).andExpect(status().isForbidden());
    verify(service,never()).cancelOrder(any());verify(service,never()).publishOrderUpdate(any());
  }
  @Test void readerCannotCancelAndTraderCanCancelOwnStoredOrder() throws Exception {
    mvc.perform(post("/orders/own/cancel").header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(service);
    var own=order("own",22214);when(service.getOrder("own")).thenReturn(own);when(service.cancelOrder("own")).thenReturn(own);
    mvc.perform(post("/orders/own/cancel").header("Authorization","Bearer "+token("trader"))).andExpect(status().isOk());
    verify(service).cancelOrder("own");verify(service).publishOrderUpdate(own);
  }
  @Test void forceFillAndUndeclaredRoutesAreDenied() throws Exception {
    for(String subject:List.of("trader","operator"))
      mvc.perform(post("/orders/own/force-fill").header("Authorization","Bearer "+token(subject))).andExpect(status().isForbidden());
    mvc.perform(get("/v3/api-docs").header("Authorization","Bearer "+token("operator"))).andExpect(status().isForbidden());
    verifyNoInteractions(service);
  }
  @Test void aggregateCountsAndSystemDetailsAreOperatorOnly() throws Exception {
    for(String path:List.of("/orders/open-count","/metrics","/health","/healthz","/system/health"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(service);
    when(service.health()).thenReturn(Map.of("status","ok"));
    mvc.perform(get("/system/health").header("Authorization","Bearer "+token("operator"))).andExpect(status().isOk());
    verify(service).health();
  }
}
