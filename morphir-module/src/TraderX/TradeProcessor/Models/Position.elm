module TraderX.TradeProcessor.Models.Position exposing (..)

import TraderX.Models.AccountId exposing (AccountId)
import TraderX.Models.Date exposing (Date)
import TraderX.Models.Quantity exposing (Quantity)
import TraderX.Models.Security exposing (Security)
import TraderX.TradeProcessor.Models.PositionQuantity exposing (PositionQuantity)


type alias Position =
    { serialVersionUID : Int
    , accountId : AccountId
    , security : Security
    , quantity : PositionQuantity
    , updated : Maybe Date
    }