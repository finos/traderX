module Traderx.Morphir.Rulesengine.TradingRules exposing (..)

import Traderx.Morphir.Rulesengine.Models.Error exposing (Errors(..))
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


cancelTrade : TradeOrder -> Result (Errors err) Bool
cancelTrade tradeOrder =
    case tradeOrder.state of
        Processing ->
            Ok True

        _ ->
            Err (CancelTradeError { code = 600, msg = "Trade State must be Processing" })


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


processTrade : TradeOrder -> Result (Errors err) Bool
processTrade trd =
    case trd.desired of
        New ->
            buyStock trd

        Cancelled ->
            cancelTrade trd

        _ ->
            Err (INVALID_TRADE_STATE { code = 900, msg = "Invalid Desired Trade State" })
