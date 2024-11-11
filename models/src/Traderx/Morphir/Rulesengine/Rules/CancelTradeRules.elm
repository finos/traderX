module Traderx.Morphir.Rulesengine.Rules.CancelTradeRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))


validateOrderState : TradeOrder -> Result String Bool
validateOrderState tradeOrder =
    case tradeOrder.state of
        New ->
            Ok True

        Processing ->
            Ok True

        Settled ->
            Err "INVALID_TRADE_STATE"

        Cancelled ->
            Err "INVALID_TRADE_STATE"


validateOrderState2 : TradeOrder -> Result String Bool
validateOrderState2 tradeOrder =
    if tradeOrder.state == New || tradeOrder.state == Processing then
        Ok True

    else
        Err "INVALID_TRADE_STATE"
