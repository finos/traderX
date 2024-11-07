module Traderx.Morphir.Rulesengine.Models.TradeMetadata exposing (..)

import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState)


type alias TradeMetadata =
    { filled : Int
    , desired : TradeState
    }
