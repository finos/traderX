package finos.traderx.positionservice.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import finos.traderx.positionservice.service.PositionService;
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

@ContextConfiguration(classes = {PositionController.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class PositionControllerDiffblueTest {
  @Autowired
  private PositionController positionController;

  @MockBean
  private PositionService positionService;

  /**
   * Test {@link PositionController#getAllPositions()}.
   * <p>
   * Method under test: {@link PositionController#getAllPositions()}
   */
  @Test
  @DisplayName("Test getAllPositions()")
  void testGetAllPositions() throws Exception {
    // Arrange
    when(positionService.getAllPositions()).thenReturn(new ArrayList<>());
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.get("/positions/");

    // Act and Assert
    MockMvcBuilders.standaloneSetup(positionController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content().string("[]"));
  }

  /**
   * Test {@link PositionController#generalError(Exception)}.
   * <ul>
   *   <li>When {@link Exception#Exception(String)} with {@code foo}.</li>
   *   <li>Then StatusCode return {@link HttpStatus}.</li>
   * </ul>
   * <p>
   * Method under test: {@link PositionController#generalError(Exception)}
   */
  @Test
  @DisplayName("Test generalError(Exception); when Exception(String) with 'foo'; then StatusCode return HttpStatus")
  void testGeneralError_whenExceptionWithFoo_thenStatusCodeReturnHttpStatus() {
    // Arrange and Act
    ResponseEntity<String> actualGeneralErrorResult = positionController.generalError(new Exception("foo"));

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
