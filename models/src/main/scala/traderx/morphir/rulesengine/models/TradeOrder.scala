package traderx.morphir.rulesengine.models

/** Generated based on Morphir.Rulesengine.Models.TradeOrder
*/
object TradeOrder{

  final case class Stock(
    security: morphir.sdk.String.String,
    quantity: morphir.sdk.Basics.Int
  ){}
  
  final case class TradeOrder(
    id: morphir.sdk.String.String,
    state: traderx.morphir.rulesengine.models.TradeState.TradeState,
    security: morphir.sdk.String.String,
    quantity: morphir.sdk.Basics.Int,
    accountId: morphir.sdk.String.String,
    side: traderx.morphir.rulesengine.models.TradeSide.TradeSide
  ){}

}