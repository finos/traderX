package __PACKAGE__.security;

import __PACKAGE__.repository.OrderRepository;
import __PACKAGE__.service.OrderMatcherService;
import __PACKAGE__.model.OrderRecord;
import __PACKAGE__.model.OrderStatus;
import __PACKAGE__.model.OrderSide;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={
  "spring.datasource.url=jdbc:h2:mem:acceptedauthority;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
  "spring.datasource.driverClassName=org.h2.Driver",
  "spring.datasource.username=sa", "spring.datasource.password=sa",
  "spring.jpa.database-platform=org.hibernate.dialect.H2Dialect",
  "spring.jpa.hibernate.ddl-auto=create-drop", "order.matcher.seed-enabled=false",
  "order.matcher.tick-ms=3600000", "order.matcher.publisher=noop",
  "order.matcher.pricing-subscriber.enabled=false"
})
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
class OrderAcceptedAuthorityTest extends SecurityTestSupport {
  @Autowired OrderRepository repository;
  @Autowired AcceptedOrderAuthority authority;
  @Autowired OrderMatcherService matcher;
  @Autowired RestTemplate rest;
  @Autowired JwtDecoder decoder;

  String create(String bearer) throws Exception {
    String result=mvc.perform(post("/orders").header("Authorization","Bearer "+bearer)
      .contentType("application/json").content("{\"accountId\":22214,\"security\":\"IBM\",\"side\":\"Buy\",\"quantity\":10,\"limitPrice\":100}"))
      .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
    assertFalse(result.contains("acceptedSubject"));
    assertFalse(result.contains(bearer));
    return com.jayway.jsonpath.JsonPath.read(result,"$.orderId");
  }

  @Test void storedAuthorityNeedsNoReusableUserToken() throws Exception {
    String bearer=token("trader");
    var jwt=decoder.decode(bearer);
    String id=create(bearer);
    SecurityContextHolder.clearContext();
    var stored=repository.findById(id).orElseThrow();
    assertEquals("trader",stored.getAcceptedSubject());
    assertEquals(ISSUER,stored.getAcceptedIssuer());
    assertFalse(stored.getAcceptedTerms().contains(bearer));
    // Model expiry without sleeping or changing the host clock. No token is supplied to authority.
    var expired=new JwtTimestampValidator(Duration.ZERO);
    expired.setClock(Clock.fixed(jwt.getExpiresAt().plusSeconds(1),ZoneOffset.UTC));
    assertTrue(expired.validate(jwt).hasErrors());
    assertDoesNotThrow(() -> authority.requireEligible(stored));
    mvc.perform(post("/orders").header("Authorization","Bearer "+token("trader",ISSUER,"traderx-api",-1,KEYS))
      .contentType("application/json").content("{}")).andExpect(status().isUnauthorized());
  }

  @Test void legacyChangedAndCanceledOrdersCannotExecute() throws Exception {
    String id=create(token("trader"));
    var original=repository.findById(id).orElseThrow();
    assertDoesNotThrow(() -> authority.requireEligible(original));
    for (String mutation:java.util.List.of("subject","issuer","terms","account","security","side","quantity","price","remaining","status","id")) {
      OrderRecord row=repository.findById(id).orElseThrow();
      switch(mutation) {
        case "subject" -> row.setAcceptedSubject(null);
        case "issuer" -> row.setAcceptedIssuer("https://untrusted.example");
        case "terms" -> row.setAcceptedTerms(null);
        case "account" -> row.setAccountId(44044);
        case "security" -> row.setSecurity("MSFT");
        case "side" -> row.setSide(OrderSide.Sell);
        case "quantity" -> row.setQuantity(20);
        case "price" -> row.setLimitPrice(new BigDecimal("101"));
        case "remaining" -> row.setRemainingQuantity(11);
        case "status" -> row.setStatus(OrderStatus.FILLED);
        case "id" -> row.setOrderId("other-order");
      }
      assertThrows(AccessDeniedException.class,()->authority.requireEligible(row),mutation);
    }
    mvc.perform(post("/orders/"+id+"/cancel").header("Authorization","Bearer "+token("trader"))).andExpect(status().isOk());
    assertThrows(AccessDeniedException.class,()->authority.requireEligible(repository.findById(id).orElseThrow()));
  }

  @Test void restartedPolicyRevokesStoredAuthority() throws Exception {
    var row=repository.findById(create(token("trader"))).orElseThrow();
    var file=Files.createTempFile("revoked-entitlements-",".txt");
    try {
      for(String policy:java.util.List.of("trader=read-only:22214", "trader=trader:44044", "other=trader:22214")) {
        Files.writeString(file,policy);
        var restarted=new AcceptedOrderAuthority(new TradingAccess(file.toString()),ISSUER);
        assertThrows(AccessDeniedException.class,()->restarted.requireEligible(row));
      }
    } finally { Files.delete(file); }
  }

  @Test void internalCreateCannotBypassAcceptance() {
    SecurityContextHolder.clearContext();
    long before=repository.count();
    var request=new __PACKAGE__.api.OrderCreateRequest();
    request.setAccountId(22214); request.setSecurity("IBM"); request.setSide(OrderSide.Buy);
    request.setQuantity(10); request.setLimitPrice(new BigDecimal("100"));
    assertThrows(AccessDeniedException.class,()->matcher.createOrder(request));
    assertEquals(before,repository.count());
  }

  @Test void schedulerRefusesAnonymousHandoffAndLeavesOrderUnchanged() throws Exception {
    String id=create(token("trader"));
    var before=repository.findById(id).orElseThrow();
    var server=MockRestServiceServer.bindTo(rest).build(); // Zero HTTP calls allowed.
    try {
      SecurityContextHolder.clearContext();
      matcher.onPriceTick("IBM",new BigDecimal("99"));
      matcher.runMatcherTick();
      var after=repository.findById(id).orElseThrow();
      assertEquals(before.getStatus(),after.getStatus());
      assertEquals(before.getRemainingQuantity(),after.getRemainingQuantity());
      assertEquals(before.getUpdatedAt(),after.getUpdatedAt());
      server.verify();
    } finally { server.reset(); }
  }
}
