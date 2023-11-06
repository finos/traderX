module TraderX.Shared.TradeResponse exposing (..)

type alias TradeResponse =
    { success : Bool
    , id : String
    , errorMessage : String
    }