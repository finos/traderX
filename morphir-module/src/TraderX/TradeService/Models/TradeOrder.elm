module TraderX.TradeService.Models.TradeOrder exposing (..)

import TraderX.Models.AccountId exposing (AccountId)
import TraderX.Models.Id exposing (ID)
import TraderX.Models.Security exposing (Security)
import TraderX.Models.State exposing (State)
import TraderX.TradeService.Models.TradeQuantity exposing (TradeQuantity)
import TraderX.TradeService.Models.TradeSide exposing (TradeSide)

type alias TradeOrder =
    { id : ID
    , state : State
    , security : Security
    , quantity : TradeQuantity
    , accountId : AccountId
    , side : TradeSide
    }