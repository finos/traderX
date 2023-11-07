package traderx.models

/** Generated based on Models.TradeState
*/
object TradeState{

  sealed trait TradeState {
  
    
  
  }
  
  object TradeState{
  
    case object Canceled extends traderx.models.TradeState.TradeState{}
    
    case object New extends traderx.models.TradeState.TradeState{}
    
    case object Processing extends traderx.models.TradeState.TradeState{}
    
    case object Settled extends traderx.models.TradeState.TradeState{}
  
  }
  
  val Canceled: traderx.models.TradeState.TradeState.Canceled.type  = traderx.models.TradeState.TradeState.Canceled
  
  val New: traderx.models.TradeState.TradeState.New.type  = traderx.models.TradeState.TradeState.New
  
  val Processing: traderx.models.TradeState.TradeState.Processing.type  = traderx.models.TradeState.TradeState.Processing
  
  val Settled: traderx.models.TradeState.TradeState.Settled.type  = traderx.models.TradeState.TradeState.Settled

}