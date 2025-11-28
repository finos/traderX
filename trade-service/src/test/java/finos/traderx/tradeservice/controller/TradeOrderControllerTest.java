package finos.traderx.tradeservice.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.PubSubException;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.model.TradeSide;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doNothing;

@WebMvcTest(TradeOrderController.class)
@TestPropertySource(properties = {
    "reference.data.service.url=http://localhost:8080",
    "account.service.url=http://localhost:8081"
})
class TradeOrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private Publisher<TradeOrder> tradePublisher;

    private RestTemplate restTemplate;

    @Autowired
    private ApplicationContext applicationContext;

    @Autowired
    private ObjectMapper objectMapper;

    private Security validSecurity;
    private Account validAccount;
    private TradeOrder validTradeOrder;

    @BeforeEach
    void setUp() throws Exception {
        // Create and inject mock RestTemplate into the controller using reflection
        restTemplate = mock(RestTemplate.class);
        TradeOrderController controller = applicationContext.getBean(TradeOrderController.class);
        Field restTemplateField = TradeOrderController.class.getDeclaredField("restTemplate");
        restTemplateField.setAccessible(true);
        restTemplateField.set(controller, restTemplate);

        // Setup valid security
        validSecurity = new Security("MSFT", "Microsoft Corporation");

        // Setup valid account
        validAccount = new Account(1, "Test Account");

        // Setup valid trade order
        validTradeOrder = new TradeOrder("TRADE-001", 1, "MSFT", TradeSide.Buy, 100);
    }

    @Test
    void testSubmitValidTradeOrder() throws Exception {
        // Arrange
        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to return valid account
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(validTradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value("TRADE-001"))
                .andExpect(jsonPath("$.accountId").value(1))
                .andExpect(jsonPath("$.security").value("MSFT"))
                .andExpect(jsonPath("$.side").value("Buy"))
                .andExpect(jsonPath("$.quantity").value(100));
    }

    @Test
    void testSubmitTradeWithInvalidSecurity() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-002", 1, "INVALID", TradeSide.Buy, 100);

        // Mock RestTemplate to throw 404 for invalid security
        HttpClientErrorException notFoundException = new HttpClientErrorException(
                HttpStatus.NOT_FOUND, "Security not found");
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenThrow(notFoundException);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());
    }

    @Test
    void testSubmitTradeWithInvalidAccount() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("TRADE-003", 999, "MSFT", TradeSide.Buy, 100);

        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to throw 404 for invalid account
        HttpClientErrorException notFoundException = new HttpClientErrorException(
                HttpStatus.NOT_FOUND, "Account not found");
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenThrow(notFoundException);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());
    }

    @Test
    void testSubmitBuyTrade() throws Exception {
        // Arrange
        TradeOrder buyTradeOrder = new TradeOrder("TRADE-004", 1, "MSFT", TradeSide.Buy, 50);

        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to return valid account
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(buyTradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.side").value("Buy"))
                .andExpect(jsonPath("$.quantity").value(50));
    }

    @Test
    void testSubmitSellTrade() throws Exception {
        // Arrange
        TradeOrder sellTradeOrder = new TradeOrder("TRADE-005", 1, "MSFT", TradeSide.Sell, 75);

        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to return valid account
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(sellTradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.side").value("Sell"))
                .andExpect(jsonPath("$.quantity").value(75));
    }

    @Test
    void testSubmitTradeWithZeroQuantity() throws Exception {
        // Arrange
        TradeOrder zeroQuantityTradeOrder = new TradeOrder("TRADE-006", 1, "MSFT", TradeSide.Buy, 0);

        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to return valid account
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        // Note: The current implementation doesn't validate quantity, so it accepts zero quantity
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(zeroQuantityTradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.quantity").value(0));
    }

    @Test
    void testSubmitTradeWithNegativeQuantity() throws Exception {
        // Arrange
        TradeOrder negativeQuantityTradeOrder = new TradeOrder("TRADE-007", 1, "MSFT", TradeSide.Buy, -50);

        // Mock RestTemplate to return valid security
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
                .thenReturn(new ResponseEntity<>(validSecurity, HttpStatus.OK));

        // Mock RestTemplate to return valid account
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
                .thenReturn(new ResponseEntity<>(validAccount, HttpStatus.OK));

        // Mock publisher to succeed
        doNothing().when(tradePublisher).publish(anyString(), any(TradeOrder.class));

        // Act & Assert
        // Note: The current implementation doesn't validate quantity, so it accepts negative quantity
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(negativeQuantityTradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.quantity").value(-50));
    }
}

