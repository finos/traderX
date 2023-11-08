module TraderX.TradeProcessor.Models.PositionID exposing (..)
import TraderX.Shared.AccountId exposing (AccountId)
import TraderX.Shared.Security exposing (Security)

type alias PositionID =
    { accountId : AccountId
    , security : Security
    }