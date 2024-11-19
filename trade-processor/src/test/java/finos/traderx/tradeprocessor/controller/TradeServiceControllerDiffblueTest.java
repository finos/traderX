package finos.traderx.tradeprocessor.controller;

import static org.mockito.Mockito.when;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.junit.jupiter.api.DisplayName;
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
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
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
  void testProcessOrder() throws Exception {
    // Arrange
    Trade t = new Trade();
    when(tradeService.processTrade(Mockito.<TradeOrder>any())).thenReturn(new TradeBookingResult(t, new Position()));
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
                "{\"trade\":{\"id\":null,\"accountId\":null,\"security\":null,\"side\":null,\"state\":\"New\",\"quantity\":null,"
                    + "\"updated\":null,\"created\":null},\"position\":{\"accountId\":null,\"security\":null,\"quantity\":null,\"updated"
                    + "\":null}}"));
  }
}
