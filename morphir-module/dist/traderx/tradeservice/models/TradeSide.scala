package traderx.tradeservice.models

/** Generated based on TradeService.Models.TradeSide
*/
object TradeSide{

  sealed trait TradeSide {
  
    
  
  }
  
  object TradeSide{
  
    case object Buy extends traderx.tradeservice.models.TradeSide.TradeSide{}
    
    case object Sell extends traderx.tradeservice.models.TradeSide.TradeSide{}
  
  }
  
  val Buy: traderx.tradeservice.models.TradeSide.TradeSide.Buy.type  = traderx.tradeservice.models.TradeSide.TradeSide.Buy
  
  val Sell: traderx.tradeservice.models.TradeSide.TradeSide.Sell.type  = traderx.tradeservice.models.TradeSide.TradeSide.Sell

}