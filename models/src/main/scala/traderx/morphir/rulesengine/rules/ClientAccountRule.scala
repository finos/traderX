package traderx.morphir.rulesengine.rules

/** Generated based on Morphir.Rulesengine.Rules.ClientAccountRule
*/
object ClientAccountRule{

  def validateIdLength(
    trdOrder: traderx.morphir.rulesengine.models.TradeOrder.TradeOrder
  ): morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool] = {
    val accountNumberLength: morphir.sdk.Basics.Int = morphir.sdk.Basics.Int(10)
    
    if (morphir.sdk.Basics.greaterThan(morphir.sdk.String.length(trdOrder.id))(accountNumberLength)) {
      (morphir.sdk.Result.Ok(true) : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
    } else {
      (morphir.sdk.Result.Err("""INVALID_ACCOUNT""") : morphir.sdk.Result.Result[morphir.sdk.String.String, morphir.sdk.Basics.Bool])
    }
  }

}