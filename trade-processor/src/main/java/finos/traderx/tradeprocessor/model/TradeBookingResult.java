package finos.traderx.tradeprocessor.model;

public class TradeBookingResult {
    Trade trade;
    Position position;
    public TradeBookingResult(Trade t, Position p){
        this.trade=t;
        this.position=p;
    }
    public Trade getTrade() {
        return trade;
    }
    public Position getPosition() {
        return position;
    }
}

