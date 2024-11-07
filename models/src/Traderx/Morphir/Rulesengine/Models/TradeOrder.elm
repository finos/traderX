module Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (..)

import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide)
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState)


type alias Stock =
    { security : String
    , quantity : Int
    }


type alias TradeOrder =
    { id : String
    , state : TradeState
    , security : String
    , quantity : Int
    , accountId : String
    , side : TradeSide

    --, portfolio : Maybe (List Stock)
    --, accountBalance : Float
    }
