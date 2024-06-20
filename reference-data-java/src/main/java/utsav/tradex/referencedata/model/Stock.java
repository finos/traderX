package utsav.tradex.referencedata.model;

public class Stock {
    private String ticker;
    private String companyName;

    public Stock(String ticker, String companyName) {
        this.ticker = ticker;
        this.companyName = companyName;
    }

    public String getTicker() {
        return ticker;
    }

    public void setTicker(String ticker) {
        this.ticker = ticker;
    }

    public String getCompanyName() {
        return companyName;
    }

    public void setCompanyName(String companyName) {
        this.companyName = companyName;
    }
}
