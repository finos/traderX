package finos.traderx.tradeprocessor.model;

public class TradeOrder {

    public String id;
    private String state;
    private String security;
    private Integer quantity;
    private Integer accountId;
    private TradeSide side;

    public TradeOrder(){}
    
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

    public String getState() {
        return state;
    }

    public Integer getAccountId() {
        return accountId;
    }

    public String getSecurity() {
        return security;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public TradeSide getSide() {
        return side;
    }
}
