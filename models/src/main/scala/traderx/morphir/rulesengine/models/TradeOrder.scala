package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.TradeOrder
*/
object TradeOrder{

  final case class TradeOrder(
    id: morphir.sdk.String.String,
    state: traderx.morphir.rulesengine.models.TradeState.TradeState,
    security: morphir.sdk.String.String,
    quantity: morphir.sdk.Basics.Int,
    accountId: morphir.sdk.Basics.Int,
    side: traderx.morphir.rulesengine.models.TradeSide.TradeSide,
    action: traderx.morphir.rulesengine.models.DesiredAction.DesiredAction,
    filled: morphir.sdk.Maybe.Maybe[morphir.sdk.Basics.Int]
  ){}

}