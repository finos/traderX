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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;

import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.controller.TradeOrderController;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.model.TradeSide;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import org.springframework.http.ResponseEntity;

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
    private Account validAccount;
    private Security validSecurity;

    @BeforeEach
    void setUp() throws Exception {
        // Create a mocked RestTemplate for integration testing
        restTemplate = mock(RestTemplate.class);
        
        // Inject the RestTemplate into the controller using reflection
        injectRestTemplate();
        
        // Setup test data
        validAccount = new Account(1, "Test Account");
        validSecurity = new Security("MSFT", "Microsoft Corporation");
    }
    
    private void injectRestTemplate() throws Exception {
        TradeOrderController controller = applicationContext.getBean(TradeOrderController.class);
        Field restTemplateField = TradeOrderController.class.getDeclaredField("restTemplate");
        restTemplateField.setAccessible(true);
        restTemplateField.set(controller, restTemplate);
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_Success() throws Exception {
        // Ensure RestTemplate is injected (controller might have been recreated)
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-001", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists (called first by controller)
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service response - account exists (called second by controller)
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

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
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class));
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_AccountNotFound() throws Exception {
        // Ensure RestTemplate is injected
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-002", 999, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service response - account not found (404)
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/999"), eq(Account.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify all expected requests were made
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/999"), eq(Account.class));
    }

    @Test
    void testTradeServiceValidatesAccountWithAccountService_AccountServiceError() throws Exception {
        // Ensure RestTemplate is injected
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-003", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service response - internal server error (500)
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class)))
                .thenThrow(new HttpServerErrorException(HttpStatus.INTERNAL_SERVER_ERROR));

        // Act & Assert
        // When Account Service returns 500, validation fails and trade is rejected
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify all expected requests were made
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class));
    }

    @Test
    void testTradeServiceAccountValidation_ValidatesAccountBeforeProcessing() throws Exception {
        // Ensure RestTemplate is injected
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-004", 1, "MSFT", TradeSide.Sell, 50);

        // Mock Reference Data Service response - security exists (called first by controller)
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service response - account exists (called second by controller)
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

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
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class));
    }

    @Test
    void testServiceUnavailable_AccountServiceDown() throws Exception {
        // Ensure RestTemplate is injected
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-005", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service as unavailable (service down - connection refused/timeout)
        // Using SERVICE_UNAVAILABLE (503) to simulate service being down
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class)))
                .thenThrow(new HttpServerErrorException(HttpStatus.SERVICE_UNAVAILABLE));

        // Act & Assert
        // When Account Service is unavailable (503), HttpServerErrorException is caught
        // and validateAccount returns false, resulting in ResourceNotFoundException (404)
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify that Account Service was called
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class));
    }

    @Test
    void testServiceUnavailable_AccountServiceConnectionTimeout() throws Exception {
        // Ensure RestTemplate is injected
        injectRestTemplate();
        
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-006", 1, "MSFT", TradeSide.Buy, 100);

        // Mock Reference Data Service response - security exists
        when(restTemplate.getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock Account Service with gateway timeout (504) to simulate connection issues
        when(restTemplate.getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class)))
                .thenThrow(new HttpServerErrorException(HttpStatus.GATEWAY_TIMEOUT));

        // Act & Assert
        // When Account Service times out (504), HttpServerErrorException is caught
        // and validateAccount returns false, resulting in ResourceNotFoundException (404)
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        // Verify that Account Service was called
        verify(restTemplate).getForEntity(eq("http://localhost:8080//stocks/MSFT"), eq(Security.class));
        verify(restTemplate).getForEntity(eq("http://localhost:8081//account/1"), eq(Account.class));
    }
}

