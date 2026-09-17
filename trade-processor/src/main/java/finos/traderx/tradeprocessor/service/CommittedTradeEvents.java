package finos.traderx.tradeprocessor.service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.BeanUtils;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** Best-effort notifications of durable bookings; delivery retries must never rebook a trade. */
final class CommittedTradeEvents {
  private static final Logger log = LoggerFactory.getLogger(CommittedTradeEvents.class);

  private CommittedTradeEvents() {}

  static void requireTransaction() {
    if (!TransactionSynchronizationManager.isActualTransactionActive()
        || !TransactionSynchronizationManager.isSynchronizationActive()) {
      throw new IllegalStateException("Trade booking requires a Spring transaction");
    }
  }

  static void publishAfterCommit(TradeBookingResult result, Publisher<Trade> trades,
      Publisher<Position> positions) {
    requireTransaction();
    // Capture each booking's values before another booking can mutate the managed entities.
    Trade trade = new Trade();
    Position position = new Position();
    BeanUtils.copyProperties(result.getTrade(), trade);
    BeanUtils.copyProperties(result.getPosition(), position);
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        log.info("Trade booking committed: {}", trade.getId());
        publish(trades, "/accounts/" + trade.getAccountId() + "/trades", trade, trade.getId());
        publish(positions, "/accounts/" + position.getAccountId() + "/positions", position, trade.getId());
      }
    });
  }

  private static <T> void publish(Publisher<T> publisher, String topic, T payload, String tradeId) {
    try {
      publisher.publish(topic, payload);
    } catch (PubSubException | RuntimeException exception) {
      // The database has committed. Propagating this error could cause callers to rebook.
      // Try the other topic independently; crash-safe delivery requires a future outbox.
      log.error("Notification failed after commit for trade {} on {}; do not rebook", tradeId, topic, exception);
    }
  }
}
