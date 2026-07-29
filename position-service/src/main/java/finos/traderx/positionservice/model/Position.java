package finos.traderx.positionservice.model;

import java.math.BigDecimal;
import java.util.Date;

public class Position {
  private Integer accountId;
  private String security;
  private Integer quantity;
  private BigDecimal averageCostBasis;
  private Date updated;

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

  public BigDecimal getAverageCostBasis() {
    return averageCostBasis;
  }

  public void setAverageCostBasis(BigDecimal averageCostBasis) {
    this.averageCostBasis = averageCostBasis;
  }

  public Date getUpdated() {
    return updated;
  }

  public void setUpdated(Date updated) {
    this.updated = updated;
  }
}
