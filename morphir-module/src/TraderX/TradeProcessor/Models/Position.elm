module TraderX.TradeProcessor.Models.Position exposing (..)
import Morphir.SDK.LocalDate exposing (..)

type alias Position =
    { serialVersionUID : Int
    , accountId : Int
    , security : String
    , quantity : Int
    , updated : Maybe String
    }