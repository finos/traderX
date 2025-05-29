package finos.traderx.tradeprocessor.controller;

import static org.mockito.Mockito.when;
import com.diffblue.cover.annotations.MethodsUnderTest;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.model.TradeSide;
import finos.traderx.tradeprocessor.model.TradeState;
import finos.traderx.tradeprocessor.service.TradeService;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

@ContextConfiguration(classes = {TradeServiceController.class})
@DisabledInAotMode
@ExtendWith(SpringExtension.class)
class TradeServiceControllerDiffblueTest {
  @MockBean
  private TradeService tradeService;

  @Autowired
  private TradeServiceController tradeServiceController;

  /**
   * Test {@link TradeServiceController#processOrder(TradeOrder)}.
   * <p>
   * Method under test: {@link TradeServiceController#processOrder(TradeOrder)}
   */
  @Test
  @DisplayName("Test processOrder(TradeOrder)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"org.springframework.http.ResponseEntity TradeServiceController.processOrder(TradeOrder)"})
  void testProcessOrder() throws Exception {
    // Arrange
    Trade t = new Trade();
    t.setAccountId(1);
    t.setCreated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    t.setId("42");
    t.setQuantity(1);
    t.setSecurity("Security");
    t.setSide(TradeSide.Buy);
    t.setState(TradeState.New);
    t.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position p = new Position();
    p.setAccountId(1);
    p.setQuantity(1);
    p.setSecurity("Security");
    p.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(tradeService.processTrade(Mockito.<TradeOrder>any())).thenReturn(new TradeBookingResult(t, p));
    MockHttpServletRequestBuilder contentTypeResult = MockMvcRequestBuilders.post("/tradeservice/order")
        .contentType(MediaType.APPLICATION_JSON);

    ObjectMapper objectMapper = new ObjectMapper();
    MockHttpServletRequestBuilder requestBuilder = contentTypeResult
        .content(objectMapper.writeValueAsString(new TradeOrder()));

    // Act and Assert
    MockMvcBuilders.standaloneSetup(tradeServiceController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content()
            .string(
                "{\"trade\":{\"id\":\"42\",\"accountId\":1,\"security\":\"Security\",\"side\":\"Buy\",\"state\":\"New\",\"quantity\":1,\"updated"
                    + "\":0,\"created\":0},\"position\":{\"accountId\":1,\"security\":\"Security\",\"quantity\":1,\"updated\":0}}"));
  }
}
