package finos.traderx.tradeservice.model;

public class SecurityPrice {

    private String ticker;
    private Integer price;

    public SecurityPrice()
    {

    }

    public SecurityPrice(String ticker, Integer price)
    {
        this.ticker = ticker;
        this.price = price;
    }
    
    public String getTicker()
    {
        return ticker;
    }

    public Integer getPrice()
    {
        return price; 
    }
}