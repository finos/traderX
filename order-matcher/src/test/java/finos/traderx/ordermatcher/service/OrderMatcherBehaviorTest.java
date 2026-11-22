package finos.traderx.ordermatcher.service;

import finos.traderx.messaging.Publisher;
import finos.traderx.ordermatcher.api.OrderCreateRequest;
import finos.traderx.ordermatcher.api.OrderResponse;
import finos.traderx.ordermatcher.model.OrderRecord;
import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderStatus;
import finos.traderx.ordermatcher.model.OrderType;
import finos.traderx.ordermatcher.repository.OrderRepository;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class OrderMatcherBehaviorTest {
    private OrderRepository repository;
    private RestTemplate tradeClient;
    private OrderMatcherService service;
    private Map<String, OrderRecord> rows;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setup() {
        rows = new LinkedHashMap<>();
        repository = mock(OrderRepository.class);
        tradeClient = mock(RestTemplate.class);
        when(repository.findAllByOrderByUpdatedAtDesc()).thenAnswer(call -> new ArrayList<>(rows.values()));
        when(repository.findById(anyString())).thenAnswer(call -> Optional.ofNullable(rows.get(call.getArgument(0))));
        when(repository.save(any(OrderRecord.class))).thenAnswer(call -> {
            OrderRecord order = call.getArgument(0);
            rows.put(order.getOrderId(), order);
            return order;
        });
        when(tradeClient.postForEntity(anyString(), any(), eq(Map.class)))
            .thenReturn(ResponseEntity.ok(Map.of()));
        service = new OrderMatcherService(repository, mock(Publisher.class), tradeClient,
            false, "http://prices", "http://trade", 1000, 1000);
    }

    private OrderCreateRequest request(OrderType type, OrderSide side) {
        OrderCreateRequest request = new OrderCreateRequest();
        request.setAccountId(22214);
        request.setSecurity("IBM");
        request.setSide(side);
        request.setQuantity(10);
        request.setOrderType(type);
        return request;
    }

    @Test
    void marketBuyFillsAtCachedPrice() { assertImmediateFill(OrderSide.Buy); }

    @Test
    void marketSellFillsAtCachedPrice() { assertImmediateFill(OrderSide.Sell); }

    private void assertImmediateFill(OrderSide side) {
        service.onPriceTick("IBM", new BigDecimal("150.25"));
        OrderResponse response = service.createOrder(request(OrderType.MARKET, side));
        assertEquals(OrderStatus.FILLED, response.getStatus());
        assertEquals(0, response.getRemainingQuantity());
        assertEquals(new BigDecimal("150.250"), response.getLastExecutionPrice());
        ArgumentCaptor<Map> payload = ArgumentCaptor.forClass(Map.class);
        verify(tradeClient).postForEntity(eq("http://trade"), payload.capture(), eq(Map.class));
        assertEquals(Map.of("security", "IBM", "quantity", 10, "accountId", 22214, "side", side.name()),
            payload.getValue());
    }

    @Test
    void queuedMarketForceFillRejectsWithoutMutationOrTrade() {
        OrderResponse order = service.createOrder(request(OrderType.MARKET, OrderSide.Buy));
        var updatedAt = order.getUpdatedAt();
        clearInvocations(repository);
        ResponseStatusException error = assertThrows(ResponseStatusException.class,
            () -> service.forceFillOrder(order.getOrderId()));
        assertEquals(400, error.getStatusCode().value());
        OrderResponse after = service.getOrder(order.getOrderId());
        assertEquals(OrderStatus.NEW, after.getStatus());
        assertEquals(10, after.getRemainingQuantity());
        assertNull(after.getLastExecutionPrice());
        assertEquals(updatedAt, after.getUpdatedAt());
        verifyNoInteractions(tradeClient);
        verify(repository, never()).save(any());
    }

    @Test
    void queuedMarketFillsOnFirstTick() {
        OrderResponse order = service.createOrder(request(OrderType.MARKET, OrderSide.Buy));
        assertEquals(OrderStatus.NEW, order.getStatus());
        verifyNoInteractions(tradeClient);
        service.onPriceTick("IBM", new BigDecimal("151"));
        assertEquals(OrderStatus.FILLED, service.getOrder(order.getOrderId()).getStatus());
        verify(tradeClient).postForEntity(anyString(), any(), eq(Map.class));
    }

    @Test
    void failedTradeLeavesOrderOpenThenRetryFills() {
        service.onPriceTick("IBM", new BigDecimal("151"));
        when(tradeClient.postForEntity(anyString(), any(), eq(Map.class)))
            .thenThrow(new RuntimeException("offline")).thenReturn(ResponseEntity.ok(Map.of()));
        OrderResponse order = service.createOrder(request(OrderType.MARKET, OrderSide.Buy));
        assertEquals(OrderStatus.NEW, order.getStatus());
        assertEquals(10, order.getRemainingQuantity());
        assertNull(order.getLastExecutionPrice());
        service.runMatcherTick();
        assertEquals(OrderStatus.FILLED, service.getOrder(order.getOrderId()).getStatus());
        verify(tradeClient, times(2)).postForEntity(anyString(), any(), eq(Map.class));
    }

    @Test
    void omittedTypeDefaultsToLimitAndRequiresPrice() {
        OrderCreateRequest request = request(null, OrderSide.Buy);
        assertThrows(ResponseStatusException.class, () -> service.createOrder(request));
        request.setLimitPrice(new BigDecimal("100"));
        OrderResponse order = service.createOrder(request);
        assertEquals(OrderType.LIMIT, order.getOrderType());
        service.onPriceTick("IBM", new BigDecimal("101"));
        assertEquals(OrderStatus.NEW, service.getOrder(order.getOrderId()).getStatus());
        verifyNoInteractions(tradeClient);
        service.onPriceTick("IBM", new BigDecimal("99"));
        assertEquals(OrderStatus.FILLED, service.getOrder(order.getOrderId()).getStatus());
    }

    @Test
    void partiallyFilledLimitCanCancel() {
        OrderResponse order = partialLimit();
        clearInvocations(tradeClient);
        assertEquals(OrderStatus.CANCELED, service.cancelOrder(order.getOrderId()).getStatus());
        verifyNoInteractions(tradeClient);
    }

    @Test
    void partiallyFilledLimitCanForceFillRemaining() {
        OrderResponse order = partialLimit();
        clearInvocations(tradeClient);
        OrderResponse filled = service.forceFillOrder(order.getOrderId());
        assertEquals(OrderStatus.FILLED, filled.getStatus());
        assertEquals(0, filled.getRemainingQuantity());
        ArgumentCaptor<Map> payload = ArgumentCaptor.forClass(Map.class);
        verify(tradeClient).postForEntity(anyString(), payload.capture(), eq(Map.class));
        assertEquals(1000, payload.getValue().get("quantity"));
    }

    private OrderResponse partialLimit() {
        OrderCreateRequest request = request(OrderType.LIMIT, OrderSide.Buy);
        request.setLimitPrice(new BigDecimal("100"));
        request.setQuantity(2000);
        OrderResponse order = service.createOrder(request);
        service.onPriceTick("IBM", new BigDecimal("99"));
        OrderResponse partial = service.getOrder(order.getOrderId());
        assertEquals(OrderStatus.PARTIALLY_FILLED, partial.getStatus());
        assertEquals(1000, partial.getRemainingQuantity());
        return partial;
    }
}
