package traderx.morphir.rulesengine

/** Generated based on Morphir.Rulesengine.TradingRules
*/
object TradingRules{

  def buyStock[Err](
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool] = {
    val validAccountIdLength: morphir.sdk.Basics.Int = morphir.sdk.Basics.Int(15)
    
    tradeOrder.state match {
      case traderx.morphir.rulesengine.models.TradeState.New => 
        tradeOrder.side match {
          case traderx.morphir.rulesengine.models.TradeSide.BUY => 
            if (morphir.sdk.Basics.equal(morphir.sdk.String.length(tradeOrder.accountId))(validAccountIdLength)) {
              (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
            } else {
              (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.INVALIDACCOUNT(traderx.morphir.rulesengine.models.Error.ErrResponse(
                code = morphir.sdk.Basics.Int(700),
                msg = """Invalid Account Length"""
              )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
            }
          case traderx.morphir.rulesengine.models.TradeSide.SELL => 
            (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.INVALIDTRADESIDE(traderx.morphir.rulesengine.models.Error.ErrResponse(
              code = morphir.sdk.Basics.Int(800),
              msg = """Invalid Trade Side"""
            )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
        }
      case _ => 
        (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.INVALIDTRADESTATE(traderx.morphir.rulesengine.models.Error.ErrResponse(
          code = morphir.sdk.Basics.Int(900),
          msg = """Invalid Trade State"""
        )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
    }
  }
  
  def cancelTrade[Err](
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  )(
    filled: morphir.sdk.Basics.Int
  ): morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool] =
    tradeOrder.state match {
      case traderx.morphir.rulesengine.models.TradeState.Processing => 
        if (morphir.sdk.Basics.equal(filled)(morphir.sdk.Basics.Int(0))) {
          (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
        } else {
          (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.CancelTradeError(traderx.morphir.rulesengine.models.Error.ErrResponse(
            code = morphir.sdk.Basics.Int(300),
            msg = """Cancelled trade must have exactly 0 filled trades"""
          )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
        }
      case _ => 
        (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.CancelTradeError(traderx.morphir.rulesengine.models.Error.ErrResponse(
          code = morphir.sdk.Basics.Int(600),
          msg = """Trade must be in a Processing state"""
        )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
    }
  
  def processTrade[Err](
    trd: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  )(
    metadata: traderx.morphir.rulesengine.models.TradeMetadata.TradeMetadata
  ): morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool] =
    metadata.desired match {
      case traderx.morphir.rulesengine.models.TradeState.New => 
        traderx.morphir.rulesengine.TradingRules.buyStock(trd)
      case traderx.morphir.rulesengine.models.TradeState.Cancelled => 
        traderx.morphir.rulesengine.TradingRules.cancelTrade(trd)(metadata.filled)
      case _ => 
        (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.INVALIDTRADESTATE(traderx.morphir.rulesengine.models.Error.ErrResponse(
          code = morphir.sdk.Basics.Int(900),
          msg = """Invalid Desired Trade State"""
        )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
    }
  
  def sellRule[Err](
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool] =
    tradeOrder.side match {
      case traderx.morphir.rulesengine.models.TradeSide.SELL => 
        (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
      case traderx.morphir.rulesengine.models.TradeSide.BUY => 
        (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.INVALIDTRADESIDE(traderx.morphir.rulesengine.models.Error.ErrResponse(
          code = morphir.sdk.Basics.Int(800),
          msg = """Invalid Trade Side"""
        )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
    }

}