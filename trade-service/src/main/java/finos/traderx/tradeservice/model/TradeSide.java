package finos.traderx.tradeservice.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "The direction of the trade, ie sell or buy order")
public enum TradeSide {
    Buy,Sell
}
