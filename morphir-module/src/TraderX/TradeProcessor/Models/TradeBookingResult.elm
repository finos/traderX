module TraderX.TradeProcessor.Models.TradeBookingResult exposing (..)
import TraderX.TradeProcessor.Models.Trade exposing (Trade)
import TraderX.TradeProcessor.Models.Position exposing (Position)

type alias TradeBookingResult =
    { trade : Trade
    , position : Position
    }