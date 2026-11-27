package __PACKAGE__.security;

import __PACKAGE__.repository.OrderRepository;
import __PACKAGE__.model.OrderStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={
  "spring.datasource.url=jdbc:h2:mem:authorization;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
  "spring.datasource.driverClassName=org.h2.Driver",
  "spring.datasource.username=sa", "spring.datasource.password=sa",
  "spring.jpa.database-platform=org.hibernate.dialect.H2Dialect",
  "spring.jpa.hibernate.ddl-auto=create-drop", "order.matcher.seed-enabled=false",
  "order.matcher.tick-ms=3600000", "order.matcher.publisher=noop",
  "order.matcher.pricing-subscriber.enabled=false"
})
@DirtiesContext(classMode=DirtiesContext.ClassMode.AFTER_CLASS)
class OrderDatabaseAuthorizationTest extends SecurityTestSupport {
  @Autowired OrderRepository repository;
  String payload(int account) { return "{\"accountId\":"+account+",\"security\":\"IBM\",\"side\":\"Buy\",\"quantity\":1,\"limitPrice\":0.001}"; }
  String create(String subject,int account) throws Exception {
    String json=mvc.perform(post("/orders").header("Authorization","Bearer "+token(subject)).contentType("application/json").content(payload(account)))
      .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
    return com.jayway.jsonpath.JsonPath.read(json,"$.orderId");
  }
  @Test void deniedCreatesAndCrossAccountCancelsLeaveStoredRowsUnchanged() throws Exception {
    assertEquals(0,repository.count());
    mvc.perform(post("/orders").header("Authorization","Bearer "+token("reader")).contentType("application/json").content(payload(22214))).andExpect(status().isForbidden());
    mvc.perform(post("/orders").header("Authorization","Bearer "+token("trader")).contentType("application/json").content(payload(44044))).andExpect(status().isForbidden());
    assertEquals(0,repository.count());
    String own=create("trader",22214), foreign=create("other",44044);
    var before=repository.findById(foreign).orElseThrow();
    mvc.perform(post("/orders/"+foreign+"/cancel?accountId=22214").header("Authorization","Bearer "+token("trader")).header("X-Role","operator")).andExpect(status().isForbidden());
    var after=repository.findById(foreign).orElseThrow();
    assertEquals(before.getStatus(),after.getStatus());assertEquals(before.getRemainingQuantity(),after.getRemainingQuantity());assertEquals(before.getUpdatedAt(),after.getUpdatedAt());assertEquals(44044,after.getAccountId());
    mvc.perform(post("/orders/"+own+"/cancel").header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    assertEquals(OrderStatus.NEW,repository.findById(own).orElseThrow().getStatus());
    mvc.perform(post("/orders/"+own+"/cancel").header("Authorization","Bearer "+token("trader"))).andExpect(status().isOk());
    assertEquals(OrderStatus.CANCELED,repository.findById(own).orElseThrow().getStatus());
    assertEquals(0,repository.findById(own).orElseThrow().getRemainingQuantity());
    assertEquals(2,repository.count());
  }
}
