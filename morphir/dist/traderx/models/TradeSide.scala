package traderx.models

/** Generated based on Models.TradeSide
*/
object TradeSide{

  sealed trait TradeSide {
  
    
  
  }
  
  object TradeSide{
  
    case object Buy extends traderx.models.TradeSide.TradeSide{}
    
    case object Sell extends traderx.models.TradeSide.TradeSide{}
  
  }
  
  val Buy: traderx.models.TradeSide.TradeSide.Buy.type  = traderx.models.TradeSide.TradeSide.Buy
  
  val Sell: traderx.models.TradeSide.TradeSide.Sell.type  = traderx.models.TradeSide.TradeSide.Sell

}