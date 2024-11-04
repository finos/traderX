module Traderx.Morphir.Rulesengine.BuyRule exposing (..)

import Traderx.Morphir.Rulesengine.Models.Error exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))
import Traderx.Morphir.Rulesengine.Models.TradeState exposing (TradeState(..))


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
