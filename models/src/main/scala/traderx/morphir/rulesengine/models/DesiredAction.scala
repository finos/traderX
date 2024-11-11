package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.DesiredAction
*/
object DesiredAction{

  sealed trait DesiredAction {
  
    
  
  }
  
  object DesiredAction{
  
    case object BUYSTOCK extends traderx.morphir.rulesengine.models.DesiredAction.DesiredAction{}
    
    case object CANCELTRADE extends traderx.morphir.rulesengine.models.DesiredAction.DesiredAction{}
    
    case object SELLSTOCK extends traderx.morphir.rulesengine.models.DesiredAction.DesiredAction{}
  
  }
  
  val BUYSTOCK: traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.BUYSTOCK.type  = traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.BUYSTOCK
  
  val CANCELTRADE: traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.CANCELTRADE.type  = traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.CANCELTRADE
  
  val SELLSTOCK: traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.SELLSTOCK.type  = traderx.morphir.rulesengine.models.DesiredAction.DesiredAction.SELLSTOCK

}