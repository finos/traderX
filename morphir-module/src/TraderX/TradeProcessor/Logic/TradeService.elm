module TraderX.TradeProcessor.Logic.TradeService exposing (..)

import TraderX.TradeProcessor.Models.TradeBookingResult exposing (TradeBookingResult)
import TraderX.TradeService.Models.TradeOrder exposing (TradeOrder)
import TraderX.TradeService.Models.TradeSide exposing (TradeSide(..))
import TraderX.TradeService.Models.TradeState exposing (TradeState(..))

calculateQuantity: TradeSide -> Int -> Int
calculateQuantity side tradeQuantity =
    if side == Buy then
        tradeQuantity * 1
    else
        tradeQuantity * -1


processTrade : TradeOrder -> TradeBookingResult
processTrade order =
    let
        trade =
            { id = order.id
            , security = order.security
            , quantity = order.quantity
            , accountId = 1
            , side = order.side
            , state =  New
            , updated = Just "LocalDate.fromParts 2000 11 12"
            , created = Just "LocalDate.fromParts 2000 11 12"
            }

        position =
            { serialVersionUID = 1
            , accountId = order.accountId
            , security = order.security
            , quantity = calculateQuantity order.side order.quantity
            , updated = Just "LocalDate.fromParts 2000 11 12"
            }
    in
    { trade = trade
    , position = position
    }

