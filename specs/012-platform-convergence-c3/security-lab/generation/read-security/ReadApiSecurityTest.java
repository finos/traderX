package __PACKAGE__.security;

import __PACKAGE__.controller.*;
import __PACKAGE__.model.*;
import __PACKAGE__.service.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ContextConfiguration(classes={ReadApiSecurityTest.Config.class,ReadSecurity.class,TradingAccess.class,PositionController.class,TradeController.class,HealthController.class})
class ReadApiSecurityTest extends SecurityTestSupport {
  @Configuration @EnableWebMvc @EnableWebSecurity
  static class Config {
    @Bean PositionService positions() {return mock(PositionService.class);}
    @Bean TradeService trades() {return mock(TradeService.class);}
  }
  @Autowired PositionService positions;
  @Autowired TradeService trades;
  @BeforeEach void resetServices() {reset(positions,trades);}
  Position position(int account) {var result=new Position();result.setAccountId(account);result.setSecurity("IBM");return result;}
  Trade trade(int account) {var result=new Trade();result.setAccountId(account);result.setId("trade-"+account);return result;}
  @Test void anonymousAndInvalidTokensCannotReachData() throws Exception {
    for(String path:List.of("/positions/","/trades/22214")) {
      mvc.perform(get(path)).andExpect(status().isUnauthorized());
      for(String invalid:List.of("broken",token("reader",ISSUER,"wrong",300,KEYS),token("reader","https://wrong.test","traderx-api",300,KEYS),token("reader",ISSUER,"traderx-api",-1,KEYS),token("reader",ISSUER,"traderx-api",300,keys())))
        mvc.perform(get(path).header("Authorization","Bearer "+invalid)).andExpect(status().isUnauthorized());
    }
    verifyNoInteractions(positions,trades);
  }
  @Test void crossAccountAccessDeniedBeforeQueryIncludingSpoofedHeaders() throws Exception {
    for(String path:List.of("/positions/44044","/trades/44044"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader")).header("X-Role","operator").header("X-Account-Id","44044"))
        .andExpect(status().isForbidden()).andExpect(content().string("Forbidden"));
    verifyNoInteractions(positions,trades);
  }
  @Test void unknownSubjectsCannotReadCollections() throws Exception {
    for(String path:List.of("/positions/","/trades/"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("unknown"))).andExpect(status().isForbidden());
    verifyNoInteractions(positions,trades);
  }
  @Test void ownPositionsAndHistoryRemainAvailable() throws Exception {
    when(positions.getPositionsByAccountID(22214)).thenReturn(List.of(position(22214)));
    when(trades.getTradesByAccountID(22214)).thenReturn(List.of(trade(22214)));
    for(String subject:List.of("reader","trader")) for(String path:List.of("/positions/22214","/trades/22214"))
      mvc.perform(get(path).header("Authorization","Bearer "+token(subject))).andExpect(status().isOk())
        .andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].accountId").value(22214));
  }
  @Test void collectionReadsQueryOnlyEntitledAccountsAndFilterBadDownstreamRows() throws Exception {
    when(positions.getPositionsByAccountID(22214)).thenReturn(List.of(position(22214),position(44044)));
    when(trades.getTradesByAccountID(22214)).thenReturn(List.of(trade(22214),trade(44044)));
    for(String path:List.of("/positions/","/trades/"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader"))).andExpect(status().isOk())
        .andExpect(jsonPath("$.length()").value(1)).andExpect(jsonPath("$[0].accountId").value(22214));
    verify(positions).getPositionsByAccountID(22214);verify(trades).getTradesByAccountID(22214);
    verifyNoMoreInteractions(positions,trades);
  }
  @Test void detailAlsoFiltersWrongAccountReturnedByDependency() throws Exception {
    when(positions.getPositionsByAccountID(22214)).thenReturn(List.of(position(44044)));
    mvc.perform(get("/positions/22214").header("Authorization","Bearer "+token("reader")))
      .andExpect(status().isOk()).andExpect(content().json("[]"));
  }
  @Test void operatorRoleDoesNotImplyAllAccountAccess() throws Exception {
    for(String path:List.of("/positions/","/trades/"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("operator")))
        .andExpect(status().isOk()).andExpect(content().json("[]"));
    mvc.perform(get("/positions/22214").header("Authorization","Bearer "+token("operator"))).andExpect(status().isForbidden());
    verifyNoInteractions(positions,trades);
  }
  @Test void detailedHealthRequiresOperator() throws Exception {
    mvc.perform(get("/health/ready").header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(positions,trades);
    when(positions.getAllPositions()).thenReturn(List.of(position(22214)));
    mvc.perform(get("/health/ready").header("Authorization","Bearer "+token("operator"))).andExpect(status().isOk());
    verify(positions).getAllPositions();
  }
  @Test void mutationDocumentationAndAliasesDenied() throws Exception {
    for(String path:List.of("/positions/","/trades/22214","/error"))
      mvc.perform(post(path).header("Authorization","Bearer "+token("trader"))).andExpect(status().isForbidden());
    for(String path:List.of("/positions","/trades","/swagger-ui/index.html","/v3/api-docs","/error"))
      mvc.perform(get(path).header("Authorization","Bearer "+token("reader"))).andExpect(status().isForbidden());
    verifyNoInteractions(positions,trades);
  }
  @Test void downstreamErrorsDoNotLeakDetails() throws Exception {
    when(positions.getPositionsByAccountID(22214)).thenThrow(new IllegalStateException("private database details"));
    mvc.perform(get("/positions/22214").header("Authorization","Bearer "+token("reader")))
      .andExpect(status().isInternalServerError()).andExpect(content().string("Read unavailable"));
  }
}
