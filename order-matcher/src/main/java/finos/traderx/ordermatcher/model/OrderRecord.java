package finos.traderx.ordermatcher.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "OrderBook")
public class OrderRecord {
    @Id
    @Column(name = "OrderId", nullable = false, length = 32)
    private String orderId;

    @Column(name = "AccountId", nullable = false)
    private Integer accountId;

    @Column(name = "Security", nullable = false, length = 16)
    private String security;

    @Enumerated(EnumType.STRING)
    @Column(name = "Side", nullable = false, length = 16)
    private OrderSide side;

    @Column(name = "Quantity", nullable = false)
    private Integer quantity;

    @Column(name = "RemainingQuantity", nullable = false)
    private Integer remainingQuantity;

    @Column(name = "LimitPrice", nullable = false, precision = 18, scale = 3)
    private BigDecimal limitPrice;

    @Enumerated(EnumType.STRING)
    @Column(name = "Status", nullable = false, length = 24)
    private OrderStatus status;

    @Column(name = "CreatedAt", nullable = false)
    private Instant createdAt;

    @Column(name = "UpdatedAt", nullable = false)
    private Instant updatedAt;

    @Column(name = "LastExecutionPrice", precision = 18, scale = 3)
    private BigDecimal lastExecutionPrice;

    @Column(name = "LastFillQuantity")
    private Integer lastFillQuantity;

    @PrePersist
    public void prePersist() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = createdAt;
        }
        if (status == null) {
            status = OrderStatus.NEW;
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = Instant.now();
    }

    public String getOrderId() {
        return orderId;
    }

    public void setOrderId(String orderId) {
        this.orderId = orderId;
    }

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

    public Integer getRemainingQuantity() {
        return remainingQuantity;
    }

    public void setRemainingQuantity(Integer remainingQuantity) {
        this.remainingQuantity = remainingQuantity;
    }

    public BigDecimal getLimitPrice() {
        return limitPrice;
    }

    public void setLimitPrice(BigDecimal limitPrice) {
        this.limitPrice = limitPrice;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public void setStatus(OrderStatus status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    public BigDecimal getLastExecutionPrice() {
        return lastExecutionPrice;
    }

    public void setLastExecutionPrice(BigDecimal lastExecutionPrice) {
        this.lastExecutionPrice = lastExecutionPrice;
    }

    public Integer getLastFillQuantity() {
        return lastFillQuantity;
    }

    public void setLastFillQuantity(Integer lastFillQuantity) {
        this.lastFillQuantity = lastFillQuantity;
    }
}

