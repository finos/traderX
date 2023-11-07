module TraderX.TradeProcessor.Logic.TradeService exposing (..)
import TraderX.Shared.TradeSide exposing (..)
import TraderX.Shared.TradeOrder exposing (TradeOrder)
import TraderX.TradeProcessor.Models.TradeBookingResult exposing (TradeBookingResult)
import TraderX.Shared.TradeState exposing (..)


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
            , accountId = 1
            , security = order.security
            , side = order.side
            , state =  New
            , quantity = order.quantity
            , updated = "2020-11-12"
            , created = "created"
            }

        position = 
            { serialVersionUID = 1
            , accountId = order.accountId
            , security = order.security
            , quantity = calculateQuantity order.side order.quantity
            , updated = "updated"
            }
    in
    { trade = trade
    , position = position
    }

