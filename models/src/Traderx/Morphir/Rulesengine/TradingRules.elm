module Traderx.Morphir.Rulesengine.TradingRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.DesiredAction exposing (DesiredAction(..))
import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))

processTrade : TradeOrder -> Result String Bool
processTrade trd =
    case trd.action of
        NEW_TRADE ->
            trd
                |> newTrade


        CANCEL_TRADE ->
            trd
                |> validateCancel


newTrade : TradeOrder -> Result String Bool
newTrade trd =
    case trd.side of
        BUY ->
            trd
                |> isQuantityPositive

        SELL ->
            trd
                |> isQuantityNegative

validateCancel : TradeOrder -> Result String Bool
validateCancel tradeOrder =
    if tradeOrder.state /= Cancelled || tradeOrder.state /= Settled || tradeOrder.filled == 0 then
        Ok True
    else
        Err "Can't Cancel Trade"


isQuantityPositive : TradeOrder -> Result String Bool
isQuantityPositive trdOrder =
    if trdOrder.quantity > 0 then
        Ok True

    else
        Err "BUY FAILED"

isQuantityNegative : TradeOrder -> Result String Bool
isQuantityNegative trdOrder =
    if trdOrder.quantity < 0 then
        Ok True

    else
       Err "SELL FAILED"