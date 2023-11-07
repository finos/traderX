package traderx.models

/** Generated based on Models.TradeOrder
*/
object TradeOrder{

  final case class TradeOrder(
    id: morphir.sdk.String.String,
    state: morphir.sdk.String.String,
    security: morphir.sdk.String.String,
    quantity: morphir.sdk.Basics.Int,
    accountId: morphir.sdk.Basics.Int,
    side: traderx.models.TradeSide.TradeSide
  ){}

}