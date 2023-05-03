package finos.traderx.tradeservice.model;

public class Account {
    private Integer id;
    private String displayName;

    public Account()
    {


    }

    public Account (Integer id,String displayName)
    {
        this.id = id;
        this.displayName = displayName;
    }

    public Integer getid()
    {
        return id;
    }
    public String getdisplayName()
    {
        return displayName;
    }
}
