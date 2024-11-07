module Traderx.Morphir.Rulesengine.TradingRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.Error exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeMetadata exposing (TradeMetadata)
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))


sellRule : TradeOrder -> Result (Errors err) Bool
sellRule tradeOrder =
    case tradeOrder.side of
        SELL ->
            Ok True

        BUY ->
            Err (INVALID_TRADE_SIDE { code = 800, msg = "Invalid Trade Side" })


cancelTrade : TradeOrder -> Int -> Result (Errors err) Bool
cancelTrade tradeOrder filled =
    case tradeOrder.state of
        Processing ->
            if filled == 0 then
                Ok True

            else
                Err (CancelTradeError { code = 300, msg = "Cancelled trade must have exactly 0 filled trades" })

        _ ->
            Err (CancelTradeError { code = 600, msg = "Trade must be in a Processing state" })


buyStock : TradeOrder -> Result (Errors err) Bool
buyStock tradeOrder =
    let
        validAccountIdLength : Int
        validAccountIdLength =
            15
    in
    case tradeOrder.state of
        New ->
            case tradeOrder.side of
                BUY ->
                    if String.length tradeOrder.accountId == validAccountIdLength then
                        Ok True

                    else
                        Err (INVALID_ACCOUNT { code = 700, msg = "Invalid Account Length" })

                SELL ->
                    Err (INVALID_TRADE_SIDE { code = 800, msg = "Invalid Trade Side" })

        _ ->
            Err (INVALID_TRADE_STATE { code = 900, msg = "Invalid Trade State" })


processTrade : TradeOrder -> TradeMetadata -> Result (Errors err) Bool
processTrade trd metadata =
    case metadata.desired of
        New ->
            buyStock trd

        Cancelled ->
            cancelTrade trd metadata.filled

        _ ->
            Err (INVALID_TRADE_STATE { code = 900, msg = "Invalid Desired Trade State" })
