package finos.traderx.tradeservice.model;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "The state of the trade, ie, New, Processing, Settled, Cancelled")
public enum TradeState {
    New, Processing, Settled, Cancelled
} 