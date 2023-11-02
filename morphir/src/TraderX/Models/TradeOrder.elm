module TraderX.Models.TradeOrder exposing (..)

import TraderX.Models.TradeSide exposing (TradeSide)
type alias TradeOrder =
    { id : String
    , state : String
    , security : String
    , quantity : Int
    , accountId : Int
    , side : TradeSide
    }