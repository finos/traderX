package traderx.morphir.rulesengine

/** Generated based on Morphir.Rulesengine.CancelTradeRule
*/
object CancelTradeRule{

  def cancelTrade[Err](
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool] =
    tradeOrder.state match {
      case traderx.morphir.rulesengine.models.TradeState.Processing => 
        (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
      case _ => 
        (morphir.sdk.Result.Err((traderx.morphir.rulesengine.models.Error.CancelTradeError(traderx.morphir.rulesengine.models.Error.ErrResponse(
          code = morphir.sdk.Basics.Int(600),
          msg = """Trade State must be Processing"""
        )) : traderx.morphir.rulesengine.models.Error.Errors[Err])) : morphir.sdk.Result.Result[traderx.morphir.rulesengine.models.Error.Errors[Err], morphir.sdk.Basics.Bool])
    }

}