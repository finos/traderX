module TraderX.Shared.TradeOrder exposing (..)

import TraderX.Shared.TradeSide exposing (TradeSide)
import TraderX.Shared.Id exposing (ID)
import TraderX.Shared.State exposing (State)
import TraderX.Shared.Security exposing (Security)
import TraderX.Shared.Quantity exposing (Quantity)
import TraderX.Shared.AccountId exposing (AccountId)
type alias TradeOrder =
    { id : ID
    , state : State
    , security : Security
    , quantity : Quantity
    , accountId : AccountId
    , side : TradeSide
    }