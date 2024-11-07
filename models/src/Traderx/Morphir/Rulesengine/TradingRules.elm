module Traderx.Morphir.Rulesengine.TradingRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.DesiredAction exposing (DesiredAction(..))
import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))
import Traderx.Morphir.Rulesengine.Rules.CancelTradeRules exposing (validateOrderState)
import Traderx.Morphir.Rulesengine.Rules.ClientAccountRule exposing (validateIdLength)



--import Traderx.Morphir.Rulesengine.Models.TradeState.Internal exposing (TradeState(..))
--sellRule : TradeOrder -> Result (Errors err) Bool
--sellRule tradeOrder =
--    case tradeOrder.side of
--        SELL ->
--            Ok True
--
--        BUY ->
--            Err (INVALID_TRADE_SIDE { code = 800, msg = "Invalid Trade Side" })
--
--
--cancelTrade : TradeOrder -> Int -> Result (Errors err) Bool
--cancelTrade tradeOrder filled =
--    case tradeOrder.state of
--        Processing ->
--            if filled == 0 then
--                Ok True
--
--            else
--                Err (CancelTradeError { code = 300, msg = "Cancelled trade must have exactly 0 filled trades" })
--
--        _ ->
--            Err (CancelTradeError { code = 600, msg = "Trade must be in a Processing state" })


processTrade : TradeOrder -> Result (Errors err) Bool
processTrade trd =
    case trd.action of
        BUY_STOCK ->
            case trd.side of
                BUY ->
                    trd
                        |> validateIdLength

                _ ->
                    Err (INVALID_TRADE_SIDE { code = 800, msg = "TradeSide Must Be BUY" })

        SELL_STOCK ->
            case trd.side of
                SELL ->
                    trd
                        |> validateIdLength

                _ ->
                    Err (INVALID_TRADE_SIDE { code = 800, msg = "TradeSide Must Be SELL" })

        CANCEL_TRADE ->
            trd
                |> validateOrderState
