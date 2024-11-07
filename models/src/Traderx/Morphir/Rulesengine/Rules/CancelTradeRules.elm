module Traderx.Morphir.Rulesengine.Rules.CancelTradeRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))


validateOrderState : TradeOrder -> Result (Errors msg) Bool
validateOrderState tradeOrder =
    case tradeOrder.state of
        New ->
            Ok True

        Processing ->
            Ok True

        Settled ->
            Err (INVALID_TRADE_STATE { code = 700, msg = "Trade Already Cancelled" })

        Cancelled ->
            Err (INVALID_TRADE_STATE { code = 700, msg = "Trade Already Cancelled" })


validateOrderState2 : TradeOrder -> Result (Errors msg) Bool
validateOrderState2 tradeOrder =
    if tradeOrder.state == New || tradeOrder.state == Processing then
        Ok True

    else
        Err (INVALID_TRADE_STATE { code = 700, msg = "Trade Already Cancelled" })



--New ->
--    Ok True
--
--Processing ->
--    Ok True
--
--Settled ->
--    Err (INVALID_TRADE_STATE { code = 700, msg = "Trade Already Cancelled" })
--
--Cancelled ->
