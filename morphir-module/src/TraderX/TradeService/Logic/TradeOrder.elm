module TraderX.TradeService.Logic.TradeOrder exposing (..)

type Ticker
    = TickerInvalid
    | TickerValid String

type Account
    = AccountInvalid 
    | AccountValid Int

type ResourceNotFound
    = AccountNotFound
    | TickerNotFound

type alias TradeOrder =
    { id : String
    , security : Ticker
    , quantity : Int
    , accountId : Account
    , side : String
    }

createTradeOrder : TradeOrder -> Result ResourceNotFound TradeOrder
createTradeOrder tradeOrder =
    let 
        validTicker =
            case tradeOrder.security of
                TickerValid _ -> 
                    Ok tradeOrder
                TickerInvalid -> 
                    Err TickerNotFound
        validAccount =
            case tradeOrder.accountId of
                AccountValid _ -> 
                    Ok tradeOrder
                AccountInvalid -> 
                    Err AccountNotFound

    in
    case validTicker of
        Err _ -> validTicker
        Ok _ -> validAccount 
