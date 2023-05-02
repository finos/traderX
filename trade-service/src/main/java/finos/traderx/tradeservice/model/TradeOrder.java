package finos.traderx.tradeservice.model;

public class TradeOrder {

    public String id;
    private String state;
    private String security;
    private Integer quantity;
    private Integer accountID;
    private TradeSide side;

    public TradeOrder(){}
    
    public TradeOrder(String id, int accountID, String security, TradeSide side, int quantity) {
        this.accountID = accountID;
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

    public Integer getAccountID() {
        return accountID;
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
