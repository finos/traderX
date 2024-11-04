module Traderx.Morphir.Rulesengine.Models.Error exposing (..)


type alias ErrResponse =
    { code : Int
    , msg : String
    }


type Errors err
    = CancelTradeError ErrResponse
    | INVALID_TRADE_SIDE ErrResponse
    | INVALID_TRADE_STATE ErrResponse
    | INVALID_ACCOUNT ErrResponse



--marketClosedError : Error
--marketClosedError =
--    { code = 600, msg = "Market is Closed" }
--
--
--marketDFDError : Error
--marketDFDError =
--    { code = 550, msg = "Market is Done-For-Day" }
--
--
--stockNotFoundError : Error
--stockNotFoundError =
--    { code = 404, msg = "Stock Not Found In Market" }
--
--
--lowClientBalanceError : Error
--lowClientBalanceError =
--    { code = 404, msg = "InSufficient Client Balance" }
--
--
--tradeStatusCancelError : Error
--tradeStatusCancelError =
--    { code = 402, msg = "Trade State Prohibits Cancellation" }
