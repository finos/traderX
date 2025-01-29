package finos.traderx.tradeservice.model;

public class TradeOrder {

    public String id;
    private String state;
    private String security;
    private Integer quantity;
    private Integer accountId;
    private TradeSide side;
    private String action;

    public TradeOrder(){}
    
    public TradeOrder(String id, int accountId, String security, TradeSide side, int quantity, String action) {
        this.accountId = accountId;
        this.security = security;
        this.side = side;
        this.quantity = quantity;
        this.id = id;
        this.action = action;
    }

    public String getId() {
        return id;
    }

    public String getAction() {
        return action;
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
