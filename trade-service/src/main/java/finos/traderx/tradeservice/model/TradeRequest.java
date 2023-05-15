package finos.traderx.tradeservice.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "Request object to initiate a trade on a specific account and details")
public class TradeRequest {

    @Schema(name = "The numeric account identifier", example = "1")
    private int accountId;

    @Schema(name = "The mnemonic of the security being traded", example = "IBM")
    private String security;

    @Schema(name = "Indicates whether this is a sell or buy trade", example = "Sell")
    private TradeSide side;

    @Schema(name = "The quantity of the stocks in the order", example = "10")
    private Integer quantity;

    public int getAccountId() {
        return accountId;
    }

    public void setAccountId(int accountId) {
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

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }
}
