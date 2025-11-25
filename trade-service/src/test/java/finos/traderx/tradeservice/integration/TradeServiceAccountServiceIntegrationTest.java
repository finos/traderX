package finos.traderx.tradeservice.integration;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.lang.reflect.Field;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.ApplicationContext;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;

import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.controller.TradeOrderController;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.model.TradeSide;

import static org.mockito.Mockito.doNothing;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

@WebMvcTest(TradeOrderController.class)
@TestPropertySource(properties = {
    "reference.data.service.url=http://localhost:8080",
    "account.service.url=http://localhost:8081"
})
class TradeServiceAccountServiceIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private Publisher<TradeOrder> tradePublisher;

    @Autowired
    private ApplicationContext applicationContext;

    @Autowired
    private ObjectMapper objectMapper;

    private RestTemplate restTemplate;
    private MockRestServiceServer mockServer;
    private Account validAccount;
    private Security validSecurity;

    @BeforeEach
    void setUp() throws Exception {
        // Create a real RestTemplate for integration testing
        restTemplate = new RestTemplate();
        
        // Create MockRestServiceServer to mock HTTP calls
        mockServer = MockRestServiceServer.createServer(restTemplate);
        
        // Reset mock server state before each test
        mockServer.reset();
        
        // Inject the RestTemplate into the controller using reflection
        TradeOrderController controller = applicationContext.getBean(TradeOrderController.class);
        Field restTemplateField = TradeOrderController.class.getDeclaredField("restTemplate");
        restTemplateField.setAccessible(true);
        restTemplateField.set(controller, restTemplate);

        // Setup test data
        validAccount = new Account(1, "Test Account");
        validSecurity = new Security("MSFT", "Microsoft Corporation");
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_Success() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-001", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Account Service response - account exists
        mockServer.expect(requestTo("http://localhost:8081//account/1"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validAccount)));

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value("TRADE-001"))
                .andExpect(jsonPath("$.accountId").value(1));

        // Verify all expected requests were made
        mockServer.verify();
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_AccountNotFound() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-002", 999, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock Account Service response - account not found (404)
        mockServer.expect(requestTo("http://localhost:8081//account/999"))
                .andRespond(withStatus(HttpStatus.NOT_FOUND));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify all expected requests were made
        mockServer.verify();
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_AccountServiceError() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-003", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock Account Service response - internal server error (500)
        mockServer.expect(requestTo("http://localhost:8081//account/1"))
                .andRespond(withStatus(HttpStatus.INTERNAL_SERVER_ERROR));

        // Act & Assert
        // When Account Service returns 500, validation fails and trade is rejected
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify all expected requests were made
        mockServer.verify();
    }

    @Test
    void testTradeServiceAccountValidation_ValidatesAccountBeforeProcessing() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-004", 1, "MSFT", TradeSide.Sell, 50);

        // Mock Account Service response - account exists
        mockServer.expect(requestTo("http://localhost:8081//account/1"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validAccount)));

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accountId").value(1))
                .andExpect(jsonPath("$.security").value("MSFT"))
                .andExpect(jsonPath("$.side").value("Sell"))
                .andExpect(jsonPath("$.quantity").value(50));

        // Verify that Account Service was called with correct URL
        mockServer.verify();
    }

    @Test
    void testServiceUnavailable_AccountServiceDown() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-005", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock Account Service as unavailable (service down - connection refused/timeout)
        // Using SERVICE_UNAVAILABLE (503) to simulate service being down
        mockServer.expect(requestTo("http://localhost:8081//account/1"))
                .andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE));

        // Act & Assert
        // When Account Service is unavailable (503), HttpServerErrorException is thrown
        // The current implementation only catches HttpClientErrorException (4xx),
        // so 5xx errors propagate and result in 500 Internal Server Error
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isInternalServerError());

        // Verify that Account Service was called
        mockServer.verify();
    }

    @Test
    void testServiceUnavailable_AccountServiceConnectionTimeout() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-006", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        mockServer.expect(requestTo("http://localhost:8080//stocks/MSFT"))
                .andRespond(withSuccess()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(objectMapper.writeValueAsString(validSecurity)));

        // Mock Account Service with gateway timeout (504) to simulate connection issues
        mockServer.expect(requestTo("http://localhost:8081//account/1"))
                .andRespond(withStatus(HttpStatus.GATEWAY_TIMEOUT));

        // Act & Assert
        // When Account Service times out (504), HttpServerErrorException is thrown
        // The current implementation only catches HttpClientErrorException (4xx),
        // so 5xx errors propagate and result in 500 Internal Server Error
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isInternalServerError());

        // Verify that Account Service was called
        mockServer.verify();
    }
}

