package finos.traderx.tradeprocessor.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Date;

@Entity
@Table(name = "TRADES")
public class Trade implements Serializable {

  @Serial
  private static final long serialVersionUID = 1L;

  @Id
  @Column(length = 100, name = "ID")
  private String id;

  @Column(name = "ACCOUNTID")
  private Integer accountId;

  @Column(length = 50, name = "SECURITY")
  private String security;

  @Enumerated(EnumType.STRING)
  @Column(length = 4, name = "SIDE")
  private TradeSide side;

  @Enumerated(EnumType.STRING)
  @Column(length = 20, name = "STATE")
  private TradeState state = TradeState.New;

  @Column(name = "QUANTITY")
  private Integer quantity;

  @Column(name = "PRICE", precision = 18, scale = 3)
  private BigDecimal price;

  @Column(name = "UPDATED")
  private Date updated;

  @Column(name = "CREATED")
  private Date created;

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
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

  public TradeSide getSide() {
    return side;
  }

  public void setSide(TradeSide side) {
    this.side = side;
  }

  public TradeState getState() {
    return state;
  }

  public void setState(TradeState state) {
    this.state = state;
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

  public Date getUpdated() {
    return updated;
  }

  public void setUpdated(Date updated) {
    this.updated = updated;
  }

  public Date getCreated() {
    return created;
  }

  public void setCreated(Date created) {
    this.created = created;
  }
}
