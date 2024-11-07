module Traderx.Morphir.Rulesengine.Rules.ClientAccountRule exposing (..)

import Traderx.Morphir.Rulesengine.Models.Errors exposing (Errors(..))
import Traderx.Morphir.Rulesengine.Models.TradeOrder exposing (TradeOrder)


validateIdLength : TradeOrder -> Result (Errors msg) Bool
validateIdLength trdOrder =
    let
        accountNumberLength : Int
        accountNumberLength =
            10
    in
    if String.length trdOrder.id > accountNumberLength then
        Ok True

    else
        Err (INVALID_ACCOUNT { code = 700, msg = "Invalid Account Length" })
