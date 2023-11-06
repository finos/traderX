module TraderX.Shared.TradeRequest exposing (..)
import TraderX.Shared.TradeSide exposing (TradeSide)

type alias TradeRequest =
    { accountId : Int
    , security : String
    , side : TradeSide
    , quantity : Int
    }