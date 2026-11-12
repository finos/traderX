package finos.traderx.ordermatcher.api;

import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderType;

import java.math.BigDecimal;

public class OrderCreateRequest {
    private Integer accountId;
    private String security;
    private OrderSide side;
    private Integer quantity;
    private OrderType orderType;
    private BigDecimal limitPrice;

    public Integer getAccountId() {
        return accountId;
    }

    public void setAccountId(Integer accountId) {
        this.accountId = accountId;
    }

    public String getSecurity() {
        return security;
    }

    public void setSecurity(String security) {
        this.security = security;
    }

    public OrderSide getSide() {
        return side;
    }

    public void setSide(OrderSide side) {
        this.side = side;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public OrderType getOrderType() {
        return orderType != null ? orderType : OrderType.LIMIT;
    }

    public void setOrderType(OrderType orderType) {
        this.orderType = orderType;
    }

    public BigDecimal getLimitPrice() {
        return limitPrice;
    }

    public void setLimitPrice(BigDecimal limitPrice) {
        this.limitPrice = limitPrice;
    }
}
