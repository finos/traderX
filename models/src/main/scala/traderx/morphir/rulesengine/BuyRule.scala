package traderx.morphir.rulesengine

/** Generated based on Morphir.Rulesengine.BuyRule
*/
object BuyRule{

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

}