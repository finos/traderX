package __PACKAGE__.security;

import __PACKAGE__.controller.*;
import __PACKAGE__.model.*;
import finos.traderx.messaging.Publisher;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.http.*;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ContextConfiguration(classes={TradeApiSecurityTest.Config.class,TradingSecurity.class,TradingAccess.class,TradeOrderController.class,SystemController.class})
class TradeApiSecurityTest extends SecurityTestSupport {
  @Configuration @EnableWebMvc @EnableWebSecurity
  static class Config {
    @Bean Publisher<TradeOrder> publisher() { return mock(Publisher.class); }
    @Bean MeterRegistry meterRegistry() { return new SimpleMeterRegistry(); }
    @Bean static org.springframework.context.support.PropertySourcesPlaceholderConfigurer properties() {
      var bean=new org.springframework.context.support.PropertySourcesPlaceholderConfigurer();
      var properties=new java.util.Properties();properties.setProperty("reference.data.service.url","http://reference");properties.setProperty("account.service.url","http://account");properties.setProperty("price.service.url","http://price");bean.setProperties(properties);return bean;
    }
  }
  @Autowired Publisher<TradeOrder> publisher;
  @Autowired TradeOrderController controller;
  RestTemplate http;
  @BeforeEach void configureDependencies() { reset(publisher);http=mock(RestTemplate.class);ReflectionTestUtils.setField(controller,"restTemplate",http); }
  @Test void unauthenticatedAndInvalidTokensCannotPublish() throws Exception {
    mvc.perform(post("/trade/").contentType("application/json").content("{\"accountId\":22214,\"quantity\":1,\"security\":\"IBM\",\"side\":\"Buy\"}")).andExpect(status().isUnauthorized());
    for(String invalid:List.of("bad",token("trader",ISSUER,"wrong",300,KEYS),token("trader","https://wrong.test","traderx-api",300,KEYS),token("trader",ISSUER,"traderx-api",-1,KEYS),token("trader",ISSUER,"traderx-api",300,keys())))
      mvc.perform(post("/trade/").header("Authorization","Bearer "+invalid).contentType("application/json").content("{\"accountId\":22214,\"quantity\":1,\"security\":\"IBM\",\"side\":\"Buy\"}")).andExpect(status().isUnauthorized());
    verifyNoInteractions(http,publisher);
  }
  @Test void readerOperatorAndUnknownAreDeniedBeforeAnyEffect() throws Exception {
    for(String subject:List.of("reader","operator-account","unknown"))
      mvc.perform(post("/trade/").header("Authorization","Bearer "+token(subject)).header("X-Role","trader").contentType("application/json").content("{\"accountId\":22214,\"quantity\":1,\"security\":\"IBM\",\"side\":\"Buy\"}")).andExpect(status().isForbidden());
    verifyNoInteractions(http,publisher);
  }
  @Test void foreignAccountsAreDeniedBeforeAnyEffect() throws Exception {
    for(String body:List.of("{\"accountId\":44044,\"quantity\":1,\"security\":\"IBM\",\"side\":\"Buy\"}","{\"accountID\":44044,\"quantity\":1,\"security\":\"IBM\",\"side\":\"Buy\"}"))
      mvc.perform(post("/trade/").header("Authorization","Bearer "+token("trader")).header("X-Account-Id","22214").contentType("application/json").content(body)).andExpect(status().isForbidden());
    verifyNoInteractions(http,publisher);
  }
  @Test void permittedTradeForwardsVerifiedTokenOnlyToAccountAndPublishes() throws Exception {
    String bearer=token("trader");
    when(http.getForEntity("http://reference/stocks/IBM",Security.class)).thenReturn(ResponseEntity.ok(new Security()));
    when(http.exchange(eq("http://account/account/22214"),eq(HttpMethod.GET),any(HttpEntity.class),eq(Account.class))).thenReturn(ResponseEntity.ok(new Account()));
    var quote=mock(PriceQuote.class);when(quote.getPrice()).thenReturn(new BigDecimal("100.123"));
    when(http.getForEntity("http://price/prices/IBM",PriceQuote.class)).thenReturn(ResponseEntity.ok(quote));
    mvc.perform(post("/trade/").header("Authorization","Bearer "+bearer).contentType("application/json").content("{\"accountId\":22214,\"security\":\"IBM\",\"quantity\":1,\"side\":\"Buy\"}")).andExpect(status().isOk());
    verify(http).exchange(eq("http://account/account/22214"),eq(HttpMethod.GET),argThat((HttpEntity<?> request)->("Bearer "+bearer).equals(request.getHeaders().getFirst("Authorization"))),eq(Account.class));
    verify(http).getForEntity("http://reference/stocks/IBM",Security.class);
    verify(http).getForEntity("http://price/prices/IBM",PriceQuote.class);
    verifyNoMoreInteractions(http);
    verify(publisher).publish(eq("/trades"),argThat(trade->trade.getAccountId()==22214));
  }
  @Test void backendDenialDoesNotPublish() throws Exception {
    when(http.getForEntity("http://reference/stocks/IBM",Security.class)).thenReturn(ResponseEntity.ok(new Security()));
    when(http.exchange(anyString(),eq(HttpMethod.GET),any(HttpEntity.class),eq(Account.class))).thenThrow(new org.springframework.web.client.HttpClientErrorException(HttpStatus.FORBIDDEN));
    mvc.perform(post("/trade/").header("Authorization","Bearer "+token("trader")).contentType("application/json").content("{\"accountId\":22214,\"security\":\"IBM\",\"quantity\":1,\"side\":\"Buy\"}")).andExpect(status().isNotFound());
    verify(http).exchange(eq("http://account/account/22214"),eq(HttpMethod.GET),any(HttpEntity.class),eq(Account.class));
    verify(publisher,never()).publish(anyString(),any());
  }
  @Test void operatorDoesNotInheritTradingAndReaderCannotInspectSystem() throws Exception {
    mvc.perform(get("/system/health").header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(publisher);
    mvc.perform(get("/system/health").header("Authorization","Bearer "+token("operator"))).andExpect(status().isOk());
    mvc.perform(get("/v3/api-docs").header("Authorization","Bearer "+token("operator"))).andExpect(status().isForbidden());
  }
}
