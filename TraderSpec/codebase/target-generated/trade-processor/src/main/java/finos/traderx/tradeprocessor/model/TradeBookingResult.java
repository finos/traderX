package finos.traderx.tradeprocessor.model;

public class TradeBookingResult {
  private Trade trade;
  private Position position;

  public TradeBookingResult() {}

  public TradeBookingResult(Trade trade, Position position) {
    this.trade = trade;
    this.position = position;
  }

  public Trade getTrade() {
    return trade;
  }

  public void setTrade(Trade trade) {
    this.trade = trade;
  }

  public Position getPosition() {
    return position;
  }

  public void setPosition(Position position) {
    this.position = position;
  }
}
