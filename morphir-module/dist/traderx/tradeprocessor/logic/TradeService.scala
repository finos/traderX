package traderx.tradeprocessor.logic

/** Generated based on TradeProcessor.Logic.TradeService
*/
object TradeService{

  def calculateQuantity(
    side: traderx.tradeservice.models.TradeSide.TradeSide
  )(
    tradeQuantity: morphir.sdk.Basics.Int
  ): morphir.sdk.Basics.Int =
    if (morphir.sdk.Basics.equal(side)((traderx.tradeservice.models.TradeSide.Buy : traderx.tradeservice.models.TradeSide.TradeSide))) {
      morphir.sdk.Basics.multiply(tradeQuantity)(morphir.sdk.Basics.Int(1))
    } else {
      morphir.sdk.Basics.multiply(tradeQuantity)(morphir.sdk.Basics.negate(morphir.sdk.Basics.Int(1)))
    }
  
  def processTrade(
    order: traderx.tradeservice.models.TradeOrder.TradeOrder
  ): traderx.tradeprocessor.models.TradeBookingResult.TradeBookingResult = {
    val trade: { def accountId: T23; def created: T22; def id: T17; def quantity: T13; def security: T9; def side: T5; def state: T3; def updated: T2 } = traderx.tradeprocessor.models.Trade.Trade(
      accountId = morphir.sdk.Basics.Int(1),
      created = (morphir.sdk.Maybe.Just("LocalDate.fromParts 2000 11 12") : morphir.sdk.Maybe.Maybe[morphir.sdk.String.String]),
      id = order.id,
      quantity = order.quantity,
      security = order.security,
      side = order.side,
      state = (traderx.tradeservice.models.TradeState.New : traderx.tradeservice.models.TradeState.TradeState),
      updated = (morphir.sdk.Maybe.Just("LocalDate.fromParts 2000 11 12") : morphir.sdk.Maybe.Maybe[morphir.sdk.String.String])
    )
    
    val position: { def accountId: T20; def quantity: T18; def security: T5; def serialVersionUID: T3; def updated: T2 } = traderx.tradeprocessor.models.Position.Position(
      accountId = order.accountId,
      quantity = traderx.tradeprocessor.logic.TradeService.calculateQuantity(order.side)(order.quantity),
      security = order.security,
      serialVersionUID = morphir.sdk.Basics.Int(1),
      updated = (morphir.sdk.Maybe.Just("LocalDate.fromParts 2000 11 12") : morphir.sdk.Maybe.Maybe[morphir.sdk.String.String])
    )
    
    traderx.tradeprocessor.models.TradeBookingResult.TradeBookingResult(
      position = position,
      trade = trade
    )
  }

}