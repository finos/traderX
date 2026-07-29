package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.nats.NatsJSONSubscriber;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.springframework.beans.factory.annotation.Autowired;

public class TradeFeedHandler extends NatsJSONSubscriber<TradeOrder> {
  static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(TradeFeedHandler.class);

  public TradeFeedHandler() {
    super(TradeOrder.class);
  }

  @Autowired
  private TradeService tradeService;

  @Override
  public void onMessage(Envelope<?> envelope, TradeOrder order) {
    try {
      tradeService.processTrade(order);
    } catch (Exception x) {
      log.error("Error processing trade order {} in envelope {}", order, envelope);
      log.error("Error handling incoming trade order:", x);
    }
  }
}
