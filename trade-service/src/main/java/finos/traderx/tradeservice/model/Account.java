package finos.traderx.tradeservice.model;

public class Account {
  private Integer id;
  private String displayName;

  public Account() {}

  public Account(Integer id, String displayName) {
    this.id = id;
    this.displayName = displayName;
  }

  public Integer getId() {
    return id;
  }

  public void setId(Integer id) {
    this.id = id;
  }

  public String getDisplayName() {
    return displayName;
  }

  public void setDisplayName(String displayName) {
    this.displayName = displayName;
  }
}
