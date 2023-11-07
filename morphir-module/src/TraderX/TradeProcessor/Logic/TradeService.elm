module TraderX.TradeProcessor.Logic.TradeService exposing (..)
import TraderX.Shared.TradeOrder exposing (TradeOrder)
import TraderX.TradeProcessor.Models.TradeBookingResult exposing (TradeBookingResult)
import TraderX.Shared.TradeState exposing (TradeState(..))
import TraderX.Shared.TradeSide exposing (TradeSide(..))
import Morphir.SDK.LocalDate as LocalDate exposing(..)


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

