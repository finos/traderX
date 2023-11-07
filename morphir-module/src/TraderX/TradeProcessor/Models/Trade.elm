module TraderX.TradeProcessor.Models.Trade exposing (..)
import TraderX.Shared.TradeSide exposing (TradeSide)
import TraderX.Shared.TradeState exposing (TradeState(..))
import Morphir.SDK.LocalDate exposing (LocalDate)
import TraderX.Shared.Id exposing (ID)
import TraderX.Shared.AccountId exposing (AccountId)
import TraderX.Shared.Security exposing (Security)
import TraderX.Shared.Quantity exposing (Quantity)

type alias Trade =
    { id : ID
    , accountId : AccountId
    , security : Security
    , side : TradeSide
    , state :  TradeState
    , quantity : Quantity
    , updated : Maybe String
    , created : Maybe String
    }