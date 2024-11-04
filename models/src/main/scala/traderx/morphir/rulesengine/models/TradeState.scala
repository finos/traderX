package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.TradeState
*/
object TradeState{

  sealed trait TradeState {
  
    
  
  }
  
  object TradeState{
  
    case object Cancelled extends traderx.morphir.rulesengine.models.TradeState.TradeState{}
    
    case object New extends traderx.morphir.rulesengine.models.TradeState.TradeState{}
    
    case object Processing extends traderx.morphir.rulesengine.models.TradeState.TradeState{}
    
    case object Settled extends traderx.morphir.rulesengine.models.TradeState.TradeState{}
  
  }
  
  val Cancelled: traderx.morphir.rulesengine.models.TradeState.TradeState.Cancelled.type  = traderx.morphir.rulesengine.models.TradeState.TradeState.Cancelled
  
  val New: traderx.morphir.rulesengine.models.TradeState.TradeState.New.type  = traderx.morphir.rulesengine.models.TradeState.TradeState.New
  
  val Processing: traderx.morphir.rulesengine.models.TradeState.TradeState.Processing.type  = traderx.morphir.rulesengine.models.TradeState.TradeState.Processing
  
  val Settled: traderx.morphir.rulesengine.models.TradeState.TradeState.Settled.type  = traderx.morphir.rulesengine.models.TradeState.TradeState.Settled

}