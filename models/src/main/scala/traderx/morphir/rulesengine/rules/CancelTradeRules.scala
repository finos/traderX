package traderx.morphir.rulesengine.rules

/** Generated based on Morphir.Rulesengine.Rules.CancelTradeRules
*/
object CancelTradeRules{

  def validateOrderState(
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool] =
    tradeOrder.state match {
      case traderx.morphir.rulesengine.models.TradeState.New => 
        (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
      case traderx.morphir.rulesengine.models.TradeState.Processing => 
        (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
      case traderx.morphir.rulesengine.models.TradeState.Settled => 
        (morphir.sdk.Result.Err("""INVALID_TRADE_STATE""") : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
      case traderx.morphir.rulesengine.models.TradeState.Cancelled => 
        (morphir.sdk.Result.Err("""INVALID_TRADE_STATE""") : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
    }
  
  def validateOrderState2(
    tradeOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool] =
    if (morphir.sdk.Basics.or(morphir.sdk.Basics.equal(tradeOrder.state)((traderx.morphir.rulesengine.models.TradeState.New : traderx.morphir.rulesengine.models.TradeState.TradeState)))(morphir.sdk.Basics.equal(tradeOrder.state)((traderx.morphir.rulesengine.models.TradeState.Processing : traderx.morphir.rulesengine.models.TradeState.TradeState)))) {
      (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
    } else {
      (morphir.sdk.Result.Err("""INVALID_TRADE_STATE""") : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
    }

}