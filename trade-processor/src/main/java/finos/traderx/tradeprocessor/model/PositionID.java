package finos.traderx.tradeprocessor.model;

import java.io.Serializable;
import java.util.Objects;

public class PositionID implements Serializable {
  private Integer accountId;
  private String security;

  public PositionID() {
    // JPA
  }

  public PositionID(Integer accountId, String security) {
    this.accountId = accountId;
    this.security = security;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    PositionID that = (PositionID) o;
    return Objects.equals(accountId, that.accountId) && Objects.equals(security, that.security);
  }

  @Override
  public int hashCode() {
    return Objects.hash(accountId, security);
  }
}
