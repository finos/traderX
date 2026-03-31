package finos.traderx.tradeprocessor.model;

import java.math.BigDecimal;
import java.math.RoundingMode;

public class TradeOrder {

  private String id;
  private String state;
  private String security;
  private Integer quantity;
  private BigDecimal price;
  private Integer accountId;
  private TradeSide side;

  public TradeOrder() {}

  public TradeOrder(String id, int accountId, String security, TradeSide side, int quantity) {
    this.accountId = accountId;
    this.security = security;
    this.side = side;
    this.quantity = quantity;
    this.id = id;
  }

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getState() {
    return state;
  }

  public void setState(String state) {
    this.state = state;
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

  public Integer getQuantity() {
    return quantity;
  }

  public void setQuantity(Integer quantity) {
    this.quantity = quantity;
  }

  public BigDecimal getPrice() {
    return price;
  }

  public void setPrice(BigDecimal price) {
    this.price = price == null ? null : price.setScale(3, RoundingMode.HALF_UP);
  }

  public TradeSide getSide() {
    return side;
  }

  public void setSide(TradeSide side) {
    this.side = side;
  }
}
