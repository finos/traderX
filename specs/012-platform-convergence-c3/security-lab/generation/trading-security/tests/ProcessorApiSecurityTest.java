package __PACKAGE__.security;

import java.util.Map;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.MapPropertySource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ContextConfiguration(classes={ProcessorApiSecurityTest.Config.class,TradingSecurity.class,ExecutionController.class},initializers=ProcessorApiSecurityTest.ExecutionTrust.class,inheritInitializers=false)
class ProcessorApiSecurityTest extends SecurityTestSupport {
  public static class ExecutionTrust extends Trust {
    public void initialize(ConfigurableApplicationContext context) {
      super.initialize(context);
      context.getEnvironment().getPropertySources().addFirst(new MapPropertySource("execution-trust",Map.of(
        "lab.identity.audience","traderx-execution","lab.execution.matcher-subject","matcher-service")));
    }
  }
  @Configuration @EnableWebMvc @EnableWebSecurity
  static class Config { @Bean JdbcTemplate jdbc() { return mock(JdbcTemplate.class); } }
  @Autowired JdbcTemplate jdbc;
  static final UUID ID=UUID.fromString("19e2fa96-3a87-42dd-b174-a3beddbb2cd9");
  String route() { return "/internal/executions/"+ID; }
  String serviceToken() { return token("matcher-service",ISSUER,"traderx-execution",300,KEYS); }
  @BeforeEach void resetJdbc() { reset(jdbc); }

  @Test void correctServiceIdentityCallsReceiptBackedSettlement() throws Exception {
    when(jdbc.queryForObject("SELECT lab_execution.settle(?)",String.class,ID)).thenReturn(ID.toString());
    mvc.perform(post(route()).header("Authorization","Bearer "+serviceToken()))
      .andExpect(status().isOk()).andExpect(jsonPath("$.tradeId").value(ID.toString()));
    verify(jdbc).queryForObject("SELECT lab_execution.settle(?)",String.class,ID);
    verifyNoMoreInteractions(jdbc);
  }
  @Test void anonymousAndInvalidTokensNeverReachDatabase() throws Exception {
    mvc.perform(post(route())).andExpect(status().isUnauthorized());
    for(String invalid:List.of("broken",token("matcher-service"),token("matcher-service",ISSUER,"traderx-execution",-1,KEYS),
      token("matcher-service","https://wrong.test","traderx-execution",300,KEYS),token("matcher-service",ISSUER,"traderx-execution",300,keys())))
      mvc.perform(post(route()).header("Authorization","Bearer "+invalid)).andExpect(status().isUnauthorized());
    verifyNoInteractions(jdbc);
  }
  @Test void userRolesAndSpoofedSubjectCannotExecute() throws Exception {
    for(String subject:List.of("trader","operator","reader","unknown"))
      mvc.perform(post(route()).header("Authorization","Bearer "+token(subject,ISSUER,"traderx-execution",300,KEYS))
        .header("X-Service-Subject","matcher-service")).andExpect(status().isForbidden());
    verifyNoInteractions(jdbc);
  }
  @Test void payloadOverridesAndInvalidIdentifiersAreRejected() throws Exception {
    mvc.perform(post(route()).header("Authorization","Bearer "+serviceToken()).contentType("application/json").content("{\"accountId\":44044,\"quantity\":100}"))
      .andExpect(status().isBadRequest());
    mvc.perform(post("/internal/executions/not-a-uuid").header("Authorization","Bearer "+serviceToken())).andExpect(status().isBadRequest());
    verifyNoInteractions(jdbc);
  }
  @Test void legacyAndAlternateRoutesAreDenied() throws Exception {
    for(String route:List.of("/tradeservice/order","/trade/","/system/health","/metrics","/error"))
      mvc.perform(post(route).header("Authorization","Bearer "+serviceToken())).andExpect(status().isForbidden());
    mvc.perform(get(route()).header("Authorization","Bearer "+serviceToken())).andExpect(status().isForbidden());
    verifyNoInteractions(jdbc);
  }
  @Test void databaseRejectionDoesNotReturnSuccess() throws Exception {
    when(jdbc.queryForObject("SELECT lab_execution.settle(?)",String.class,ID)).thenThrow(
      new org.springframework.dao.DataIntegrityViolationException("private SQL",new java.sql.SQLException("private details","22023")));
    var response=mvc.perform(post(route()).header("Authorization","Bearer "+serviceToken()))
      .andExpect(status().isConflict()).andReturn().getResponse();
    assertFalse(response.getContentAsString().contains("private"));
  }
  @Test void wrongAudienceConfigurationFailsClosed() {
    assertThrows(IllegalArgumentException.class,()->new TradingSecurity().jwtDecoder(ISSUER,"traderx-api","/absent","2027-01-01T00:00:00Z"));
  }
}
