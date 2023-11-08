package traderx.tradeservice.models

/** Generated based on TradeService.Models.TradeState
*/
object TradeState{

  sealed trait TradeState {
  
    
  
  }
  
  object TradeState{
  
    case object Canceled extends traderx.tradeservice.models.TradeState.TradeState{}
    
    case object New extends traderx.tradeservice.models.TradeState.TradeState{}
    
    case object Processing extends traderx.tradeservice.models.TradeState.TradeState{}
    
    case object Settled extends traderx.tradeservice.models.TradeState.TradeState{}
  
  }
  
  val Canceled: traderx.tradeservice.models.TradeState.TradeState.Canceled.type  = traderx.tradeservice.models.TradeState.TradeState.Canceled
  
  val New: traderx.tradeservice.models.TradeState.TradeState.New.type  = traderx.tradeservice.models.TradeState.TradeState.New
  
  val Processing: traderx.tradeservice.models.TradeState.TradeState.Processing.type  = traderx.tradeservice.models.TradeState.TradeState.Processing
  
  val Settled: traderx.tradeservice.models.TradeState.TradeState.Settled.type  = traderx.tradeservice.models.TradeState.TradeState.Settled

}