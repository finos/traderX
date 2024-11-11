module Traderx.Morphir.Rulesengine.TradingRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.DesiredAction exposing (DesiredAction(..))
import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))
import Traderx.Morphir.Rulesengine.Rules.CancelTradeRules exposing (validateOrderState)
import Traderx.Morphir.Rulesengine.Rules.ClientAccountRule exposing (validateIdLength)


processTrade : TradeOrder -> Result String Bool
processTrade trd =
    case trd.action of
        BUY_STOCK ->
            case trd.side of
                BUY ->
                    trd
                        |> validateIdLength

                _ ->
                    Err "INVALID_TRADE_SIDE"

        SELL_STOCK ->
            case trd.side of
                SELL ->
                    trd
                        |> validateIdLength

                _ ->
                    Err "INVALID_TRADE_SIDE "

        CANCEL_TRADE ->
            trd
                |> validateOrderState
