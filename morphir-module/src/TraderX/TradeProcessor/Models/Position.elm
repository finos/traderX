module TraderX.TradeProcessor.Models.Position exposing (..)
import Morphir.SDK.LocalDate exposing (..)
import TraderX.Shared.Security exposing (Security)
import TraderX.Shared.Quantity exposing (Quantity)
import TraderX.Shared.AccountId exposing (AccountId)

type alias Position =
    { serialVersionUID : Int
    , accountId : AccountId
    , security : Security
    , quantity : Quantity
    , updated : Maybe String
    }