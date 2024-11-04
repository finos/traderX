module Traderx.Morphir.Rulesengine.SellRule exposing (..)

import Traderx.Morphir.Rulesengine.Models.Error exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (Stock, TradeOrder)
import Traderx.Morphir.Rulesengine.Models.TradeSide exposing (TradeSide(..))


sellRule : TradeOrder -> Result (Errors err) Bool
sellRule tradeOrder =
    case tradeOrder.side of
        SELL ->
            Ok True

        BUY ->
            Err (INVALID_TRADE_SIDE { code = 800, msg = "Invalid Trade Side" })
