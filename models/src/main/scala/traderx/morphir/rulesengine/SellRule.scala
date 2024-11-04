package traderx.morphir.rulesengine

/** Generated based on Morphir.Rulesengine.SellRule
*/
object SellRule{

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