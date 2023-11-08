package traderx.tradeprocessor.models

/** Generated based on TradeProcessor.Models.Trade
*/
object Trade{

  final case class Trade(
    id: traderx.models.Id.ID,
    accountId: traderx.models.AccountId.AccountId,
    security: traderx.models.Security.Security,
    side: traderx.tradeservice.models.TradeSide.TradeSide,
    state: traderx.tradeservice.models.TradeState.TradeState,
    quantity: traderx.tradeservice.models.TradeQuantity.TradeQuantity,
    updated: morphir.sdk.Maybe.Maybe[traderx.models.Date.Date],
    created: morphir.sdk.Maybe.Maybe[traderx.models.Date.Date]
  ){}

}