module Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (..)

import Traderx.Morphir.Rulesengine.Models.DesiredAction exposing (DesiredAction)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide)
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState)


type alias TradeOrder =
    { id : String
    , state : TradeState
    , security : String
    , quantity : Int
    , accountId : Int
    , side : TradeSide
    , action : DesiredAction
    , filled : Int
    }
