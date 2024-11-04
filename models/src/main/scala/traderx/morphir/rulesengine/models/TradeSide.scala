package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.TradeSide
*/
object TradeSide{

  sealed trait TradeSide {
  
    
  
  }
  
  object TradeSide{
  
    case object BUY extends traderx.morphir.rulesengine.models.TradeSide.TradeSide{}
    
    case object SELL extends traderx.morphir.rulesengine.models.TradeSide.TradeSide{}
  
  }
  
  val BUY: traderx.morphir.rulesengine.models.TradeSide.TradeSide.BUY.type  = traderx.morphir.rulesengine.models.TradeSide.TradeSide.BUY
  
  val SELL: traderx.morphir.rulesengine.models.TradeSide.TradeSide.SELL.type  = traderx.morphir.rulesengine.models.TradeSide.TradeSide.SELL

}