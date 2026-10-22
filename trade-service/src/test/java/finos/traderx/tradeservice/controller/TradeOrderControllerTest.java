package finos.traderx.tradeservice.controller;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.PubSubException;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.*;

/**
 * Tests for TradeOrderController that focus on:
 * 1. Trade order validation logic (security and account validation)
 * 2. Integration with external services via RestTemplate
 * 3. Publishing trade orders to the message bus
 * 4. Error handling for various scenarios
 */
class TradeOrderControllerTest {

    @Mock
    private Publisher<TradeOrder> tradePublisher;

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private TradeOrderController controller;

    @BeforeEach
    void setup() {
        MockitoAnnotations.openMocks(this);
        ReflectionTestUtils.setField(controller, "referenceDataServiceAddress", "http://reference-data:8080");
        ReflectionTestUtils.setField(controller, "accountServiceAddress", "http://account-service:8080");
        ReflectionTestUtils.setField(controller, "restTemplate", restTemplate);
    }

    @Test
    void createTradeOrder_ValidOrder_SuccessfullyPublished() throws PubSubException {
        // Arrange
        TradeOrder order = new TradeOrder("123", 456, "AAPL", TradeSide.Buy, 100);
        
        // Mock successful validation responses
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
            .thenReturn(ResponseEntity.ok(new Security()));
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
            .thenReturn(ResponseEntity.ok(new Account()));

        // Act
        ResponseEntity<TradeOrder> response = controller.createTradeOrder(order);

        // Assert
        assertNotNull(response);
        assertEquals(200, response.getStatusCode().value());
        assertEquals(order, response.getBody());
        verify(tradePublisher).publish("/trades", order);
    }

    @Test
    void createTradeOrder_InvalidSecurity_ThrowsResourceNotFoundException() throws PubSubException {
        // Arrange
        TradeOrder order = new TradeOrder("123", 456, "INVALID", TradeSide.Buy, 100);
        
        // Mock 404 response for security validation
        when(restTemplate.getForEntity(contains("/stocks/"), eq(Security.class)))
            .thenThrow(HttpClientErrorException.NotFound.class);

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> controller.createTradeOrder(order));
        verify(tradePublisher, never()).publish(anyString(), any());
    }

    @Test
    void createTradeOrder_InvalidAccount_ThrowsResourceNotFoundException() throws PubSubException {
        // Arrange
        TradeOrder order = new TradeOrder("123", 999, "AAPL", TradeSide.Buy, 100);
        
        // Mock successful security validation but failed account validation
        when(restTemplate.getForEntity(contains("/stocks/"), eq(Security.class)))
            .thenReturn(ResponseEntity.ok(new Security()));
        when(restTemplate.getForEntity(contains("/account/"), eq(Account.class)))
            .thenThrow(HttpClientErrorException.NotFound.class);

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> controller.createTradeOrder(order));
        verify(tradePublisher, never()).publish(anyString(), any());
    }

    @Test
    void createTradeOrder_PublishError_ThrowsRuntimeException() throws PubSubException {
        // Arrange
        TradeOrder order = new TradeOrder("123", 456, "AAPL", TradeSide.Buy, 100);
        
        // Mock successful validations but failed publish
        when(restTemplate.getForEntity(anyString(), eq(Security.class)))
            .thenReturn(ResponseEntity.ok(new Security()));
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
            .thenReturn(ResponseEntity.ok(new Account()));
        doThrow(new PubSubException("Failed to publish"))
            .when(tradePublisher).publish(anyString(), any());

        // Act & Assert
        assertThrows(RuntimeException.class, () -> controller.createTradeOrder(order));
    }
}
