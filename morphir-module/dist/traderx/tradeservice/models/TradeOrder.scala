package traderx.tradeservice.models

/** Generated based on TradeService.Models.TradeOrder
*/
object TradeOrder{

  final case class TradeOrder(
    id: traderx.models.Id.ID,
    state: traderx.models.State.State,
    security: traderx.models.Security.Security,
    quantity: traderx.tradeservice.models.TradeQuantity.TradeQuantity,
    accountId: traderx.models.AccountId.AccountId,
    side: traderx.tradeservice.models.TradeSide.TradeSide
  ){}

}