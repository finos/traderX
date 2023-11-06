module TraderX.Shared.TradeOrder exposing (..)

import TraderX.Shared.TradeSide exposing (TradeSide)
type alias TradeOrder =
    { id : String
    , state : String
    , security : String
    , quantity : Int
    , accountId : Int
    , side : TradeSide
    }