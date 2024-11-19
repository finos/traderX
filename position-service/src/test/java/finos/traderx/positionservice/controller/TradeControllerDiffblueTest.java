package finos.traderx.positionservice.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import finos.traderx.positionservice.service.TradeService;
import java.util.ArrayList;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

@ContextConfiguration(classes = {TradeController.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class TradeControllerDiffblueTest {
  @Autowired
  private TradeController tradeController;

  @MockBean
  private TradeService tradeService;

  /**
   * Test {@link TradeController#getAllTrades()}.
   * <p>
   * Method under test: {@link TradeController#getAllTrades()}
   */
  @Test
  @DisplayName("Test getAllTrades()")
  void testGetAllTrades() throws Exception {
    // Arrange
    when(tradeService.getAllTrades()).thenReturn(new ArrayList<>());
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.get("/trades/");

    // Act and Assert
    MockMvcBuilders.standaloneSetup(tradeController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content().string("[]"));
  }

  /**
   * Test {@link TradeController#generalError(Exception)}.
   * <ul>
   *   <li>When {@link Exception#Exception(String)} with {@code foo}.</li>
   *   <li>Then StatusCode return {@link HttpStatus}.</li>
   * </ul>
   * <p>
   * Method under test: {@link TradeController#generalError(Exception)}
   */
  @Test
  @DisplayName("Test generalError(Exception); when Exception(String) with 'foo'; then StatusCode return HttpStatus")
  void testGeneralError_whenExceptionWithFoo_thenStatusCodeReturnHttpStatus() {
    // Arrange and Act
    ResponseEntity<String> actualGeneralErrorResult = tradeController.generalError(new Exception("foo"));

    // Assert
    HttpStatusCode statusCode = actualGeneralErrorResult.getStatusCode();
    assertTrue(statusCode instanceof HttpStatus);
    assertEquals("foo", actualGeneralErrorResult.getBody());
    assertEquals(500, actualGeneralErrorResult.getStatusCodeValue());
    assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, statusCode);
    assertTrue(actualGeneralErrorResult.hasBody());
    assertTrue(actualGeneralErrorResult.getHeaders().isEmpty());
  }
}
