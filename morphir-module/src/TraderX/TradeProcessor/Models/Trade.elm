module TraderX.TradeProcessor.Models.Trade exposing (..)
import TraderX.Shared.TradeSide exposing (TradeSide)
import TraderX.Shared.TradeState exposing (TradeState(..))

type alias Trade =
    { id : String
    , accountId : Int
    , security : String
    , side : TradeSide
    , state :  TradeState  -- change the state from tradestate to tradestate.new
    , quantity : Int
    , updated : String
    , created : String
    }