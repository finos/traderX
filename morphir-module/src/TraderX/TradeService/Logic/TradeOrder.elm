module TraderX.TradeService.Logic.TradeOrder exposing (..)
import TraderX.TradeService.Models.Security exposing (Security)
import TraderX.Shared.AccountId exposing (AccountId)
import TraderX.Shared.TradeSide exposing (TradeSide)
import TraderX.Shared.Id exposing (ID)

type Ticker
    = TickerInvalid
    | TickerValid Security

type Account
    = AccountInvalid 
    | AccountValid AccountId

type ResourceNotFound
    = AccountNotFound
    | TickerNotFound

type alias TradeOrder =
    { id : ID
    , security : Ticker
    , quantity : Int
    , accountId : Account
    , side : TradeSide
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
