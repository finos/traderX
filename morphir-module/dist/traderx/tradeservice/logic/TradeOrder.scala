package traderx.tradeservice.logic

/** Generated based on TradeService.Logic.TradeOrder
*/
object TradeOrder{

  sealed trait Account {
  
    
  
  }
  
  object Account{
  
    case object AccountInvalid extends traderx.tradeservice.logic.TradeOrder.Account{}
    
    final case class AccountValid(
      arg1: traderx.models.AccountId.AccountId
    ) extends traderx.tradeservice.logic.TradeOrder.Account{}
  
  }
  
  val AccountInvalid: traderx.tradeservice.logic.TradeOrder.Account.AccountInvalid.type  = traderx.tradeservice.logic.TradeOrder.Account.AccountInvalid
  
  val AccountValid: traderx.tradeservice.logic.TradeOrder.Account.AccountValid.type  = traderx.tradeservice.logic.TradeOrder.Account.AccountValid
  
  sealed trait ResourceNotFound {
  
    
  
  }
  
  object ResourceNotFound{
  
    case object AccountNotFound extends traderx.tradeservice.logic.TradeOrder.ResourceNotFound{}
    
    case object TickerNotFound extends traderx.tradeservice.logic.TradeOrder.ResourceNotFound{}
  
  }
  
  val AccountNotFound: traderx.tradeservice.logic.TradeOrder.ResourceNotFound.AccountNotFound.type  = traderx.tradeservice.logic.TradeOrder.ResourceNotFound.AccountNotFound
  
  val TickerNotFound: traderx.tradeservice.logic.TradeOrder.ResourceNotFound.TickerNotFound.type  = traderx.tradeservice.logic.TradeOrder.ResourceNotFound.TickerNotFound
  
  sealed trait Ticker {
  
    
  
  }
  
  object Ticker{
  
    case object TickerInvalid extends traderx.tradeservice.logic.TradeOrder.Ticker{}
    
    final case class TickerValid(
      arg1: traderx.tradeservice.models.Security.Security
    ) extends traderx.tradeservice.logic.TradeOrder.Ticker{}
  
  }
  
  val TickerInvalid: traderx.tradeservice.logic.TradeOrder.Ticker.TickerInvalid.type  = traderx.tradeservice.logic.TradeOrder.Ticker.TickerInvalid
  
  val TickerValid: traderx.tradeservice.logic.TradeOrder.Ticker.TickerValid.type  = traderx.tradeservice.logic.TradeOrder.Ticker.TickerValid
  
  final case class TradeOrder(
    id: traderx.models.Id.ID,
    security: traderx.tradeservice.logic.TradeOrder.Ticker,
    quantity: traderx.tradeservice.models.TradeQuantity.TradeQuantity,
    accountId: traderx.tradeservice.logic.TradeOrder.Account,
    side: traderx.tradeservice.models.TradeSide.TradeSide
  ){}
  
  def createTradeOrder(
    tradeOrder: traderx.tradeservice.logic.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[traderx.tradeservice.logic.TradeOrder.ResourceNotFound, traderx.tradeservice.logic.TradeOrder.TradeOrder] = {
    val validTicker: T4 = tradeOrder.security match {
      case traderx.tradeservice.logic.TradeOrder.TickerValid(_) => 
        (morphir.sdk.Result.Ok(tradeOrder) : morphir.sdk.Result.Result[traderx.tradeservice.logic.TradeOrder.ResourceNotFound, traderx.tradeservice.logic.TradeOrder.TradeOrder])
      case traderx.tradeservice.logic.TradeOrder.TickerInvalid => 
        (morphir.sdk.Result.Err((traderx.tradeservice.logic.TradeOrder.TickerNotFound : traderx.tradeservice.logic.TradeOrder.ResourceNotFound)) : morphir.sdk.Result.Result[traderx.tradeservice.logic.TradeOrder.ResourceNotFound, traderx.tradeservice.logic.TradeOrder.TradeOrder])
    }
    
    val validAccount: T4 = tradeOrder.accountId match {
      case traderx.tradeservice.logic.TradeOrder.AccountValid(_) => 
        (morphir.sdk.Result.Ok(tradeOrder) : morphir.sdk.Result.Result[traderx.tradeservice.logic.TradeOrder.ResourceNotFound, traderx.tradeservice.logic.TradeOrder.TradeOrder])
      case traderx.tradeservice.logic.TradeOrder.AccountInvalid => 
        (morphir.sdk.Result.Err((traderx.tradeservice.logic.TradeOrder.AccountNotFound : traderx.tradeservice.logic.TradeOrder.ResourceNotFound)) : morphir.sdk.Result.Result[traderx.tradeservice.logic.TradeOrder.ResourceNotFound, traderx.tradeservice.logic.TradeOrder.TradeOrder])
    }
    
    validTicker match {
      case morphir.sdk.Result.Err(_) => 
        validTicker
      case morphir.sdk.Result.Ok(_) => 
        validAccount
    }
  }

}