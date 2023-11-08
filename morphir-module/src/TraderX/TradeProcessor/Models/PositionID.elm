module TraderX.TradeProcessor.Models.PositionID exposing (..)
import TraderX.Models.AccountId exposing (AccountId)
import TraderX.Models.Security exposing (Security)


type alias PositionID =
    { accountId : AccountId
    , security : Security
    }