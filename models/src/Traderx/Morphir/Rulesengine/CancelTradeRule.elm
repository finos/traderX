module Traderx.Morphir.Rulesengine.CancelTradeRule exposing (..)

import Traderx.Morphir.Rulesengine.Models.Error exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))


cancelTrade : TradeOrder -> Result (Errors err) Bool
cancelTrade tradeOrder =
    case tradeOrder.state of
        Processing ->
            Ok True

        _ ->
            Err (CancelTradeError { code = 600, msg = "Trade State must be Processing" })
