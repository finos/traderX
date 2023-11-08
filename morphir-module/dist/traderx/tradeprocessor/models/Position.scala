package traderx.tradeprocessor.models

/** Generated based on TradeProcessor.Models.Position
*/
object Position{

  final case class Position(
    serialVersionUID: morphir.sdk.Basics.Int,
    accountId: traderx.models.AccountId.AccountId,
    security: traderx.models.Security.Security,
    quantity: traderx.tradeprocessor.models.PositionQuantity.PositionQuantity,
    updated: morphir.sdk.Maybe.Maybe[traderx.models.Date.Date]
  ){}

}