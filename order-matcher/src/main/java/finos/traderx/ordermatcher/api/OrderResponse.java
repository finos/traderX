package finos.traderx.ordermatcher.api;

import finos.traderx.ordermatcher.model.OrderRecord;
import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderStatus;

import java.math.BigDecimal;
import java.time.Instant;

public class OrderResponse {
    private String orderId;
    private Integer accountId;
    private String security;
    private OrderSide side;
    private Integer quantity;
    private Integer remainingQuantity;
    private BigDecimal limitPrice;
    private OrderStatus status;
    private Instant createdAt;
    private Instant updatedAt;
    private BigDecimal lastExecutionPrice;
    private Integer lastFillQuantity;
    private BigDecimal marketPrice;

    public static OrderResponse from(OrderRecord order, BigDecimal marketPrice) {
        OrderResponse response = new OrderResponse();
        response.orderId = order.getOrderId();
        response.accountId = order.getAccountId();
        response.security = order.getSecurity();
        response.side = order.getSide();
        response.quantity = order.getQuantity();
        response.remainingQuantity = order.getRemainingQuantity();
        response.limitPrice = order.getLimitPrice();
        response.status = order.getStatus();
        response.createdAt = order.getCreatedAt();
        response.updatedAt = order.getUpdatedAt();
        response.lastExecutionPrice = order.getLastExecutionPrice();
        response.lastFillQuantity = order.getLastFillQuantity();
        response.marketPrice = marketPrice;
        return response;
    }

    public String getOrderId() {
        return orderId;
    }

    public Integer getAccountId() {
        return accountId;
    }

    public String getSecurity() {
        return security;
    }

    public OrderSide getSide() {
        return side;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public Integer getRemainingQuantity() {
        return remainingQuantity;
    }

    public BigDecimal getLimitPrice() {
        return limitPrice;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public BigDecimal getLastExecutionPrice() {
        return lastExecutionPrice;
    }

    public Integer getLastFillQuantity() {
        return lastFillQuantity;
    }

    public BigDecimal getMarketPrice() {
        return marketPrice;
    }
}

