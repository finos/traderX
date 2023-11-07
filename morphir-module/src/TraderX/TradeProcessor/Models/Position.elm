module TraderX.TradeProcessor.Models.Position exposing (..)


type alias Position =
    { serialVersionUID : Int
    , accountId : Int
    , security : String
    , quantity : Int
    , updated : String
    }