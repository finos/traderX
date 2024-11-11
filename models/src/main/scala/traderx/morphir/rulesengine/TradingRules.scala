package traderx.morphir.rulesengine

/** Generated based on Morphir.Rulesengine.TradingRules
*/
object TradingRules{

  def processTrade(
    trd: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool] =
    trd.action match {
      case traderx.morphir.rulesengine.models.DesiredAction.BUYSTOCK => 
        trd.side match {
          case traderx.morphir.rulesengine.models.TradeSide.BUY => 
            traderx.morphir.rulesengine.rules.ClientAccountRule.validateIdLength(trd)
          case _ => 
            (morphir.sdk.Result.Err("""INVALID_TRADE_SIDE""") : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
        }
      case traderx.morphir.rulesengine.models.DesiredAction.SELLSTOCK => 
        trd.side match {
          case traderx.morphir.rulesengine.models.TradeSide.SELL => 
            traderx.morphir.rulesengine.rules.ClientAccountRule.validateIdLength(trd)
          case _ => 
            (morphir.sdk.Result.Err("""INVALID_TRADE_SIDE """) : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
        }
      case traderx.morphir.rulesengine.models.DesiredAction.CANCELTRADE => 
        traderx.morphir.rulesengine.rules.CancelTradeRules.validateOrderState(trd)
    }

}