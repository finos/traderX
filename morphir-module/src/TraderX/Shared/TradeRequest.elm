module TraderX.Shared.TradeRequest exposing (..)
import TraderX.Shared.TradeSide exposing (TradeSide)
import TraderX.Shared.Quantity exposing (Quantity)
import TraderX.Shared.Security exposing (Security)
import TraderX.Shared.AccountId exposing (AccountId)

type alias TradeRequest =
    { accountId : AccountId
    , security : Security
    , side : TradeSide
    , quantity : Quantity
    }