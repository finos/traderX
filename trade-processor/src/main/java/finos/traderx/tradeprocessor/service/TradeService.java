package finos.traderx.tradeprocessor.service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.annotations.Validate;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.repository.PositionRepository;
import finos.traderx.tradeprocessor.repository.TradeRepository;
import java.util.Date;
import java.util.Optional;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import morphir.sdk.Maybe;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;
import traderx.morphir.rulesengine.models.TradeSide;
import traderx.morphir.rulesengine.models.TradeState;

@Service
public class TradeService {
  Logger log = LoggerFactory.getLogger(TradeService.class);

  private ConcurrentLinkedQueue<TradeOrder> queue =
      new ConcurrentLinkedQueue<>();

  @Autowired TradeRepository tradeRepository;

  @Autowired PositionRepository positionRepository;

  @Autowired private Publisher<Trade> tradePublisher;

  @Autowired private Publisher<Position> positionPublisher;

  @Validate(desired = traderx.morphir.rulesengine.models
                          .DesiredAction$DesiredAction$BUYSTOCK$.class)
  public TradeBookingResult
  makeNewTrade(TradeOrder order) {
    log.info("Trade order received : " + order);
    Trade t = new Trade();

    t.setAccountId(Integer.valueOf(order.accountId()));

    log.info("Setting a random TradeID");

    t.setId(UUID.randomUUID().toString());
    t.setCreated(new Date());
    t.setUpdated(new Date());
    t.setSecurity(order.security());
    t.setSide(order.side());
    t.setQuantity(order.quantity());
    t.setState(TradeState.New());

    Position position = positionRepository.findByAccountIdAndSecurity(
        Integer.valueOf(order.accountId()), order.security());

    log.info("Position for " + order.accountId() + " " + order.security() +
             " is " + position);

    if (position == null) {
      log.info("Creating new position for " + order.accountId() + " " +
               order.security());
      position = new Position();
      position.setAccountId(Integer.valueOf(order.accountId()));
      position.setSecurity(order.security());
      position.setQuantity(0);
    }

    log.info("Trade {}", t);
    tradeRepository.save(t);
    positionRepository.save(position);

    // Now mark as processing
    t.setUpdated(new Date());
    t.setState(TradeState.Processing());

    try {
      publish(position, t, order.accountId());
    } catch (PubSubException exc) {
      log.error("Error publishing trade " + order, exc);
    }

    queue.offer(order);

    return new TradeBookingResult(t, position);
  }

  void simulateProcessing() {
    try {
      int random = new Random().nextInt(20) + 11;
      Thread.sleep(random * 1000);
    } catch (Exception e) {
      log.warn(e.getLocalizedMessage());
    }
  }

  void publish(Position pos, Trade trade, Integer accountId)
      throws PubSubException {
    tradePublisher.publish("/accounts/" + accountId + "/trades", trade);
    positionPublisher.publish("/accounts/" + accountId + "/positions", pos);
  }

  TradeOrder createCancelledOrder(TradeOrder order, int filled) {
    return new TradeOrder(
        order.id(), order.state(), order.security(), order.quantity(),
        order.accountId(), order.side(),
        traderx.morphir.rulesengine.models.DesiredAction.CANCELTRADE(),
        new Maybe.Just<>(filled));
  }

  public Optional<TradeOrder> prepareCancelledOrder(String orderId) {
    for (TradeOrder tradeOrder : queue) {
      if (tradeOrder.id() == orderId) {
        Position position = positionRepository.findByAccountIdAndSecurity(
          Integer.valueOf(tradeOrder.accountId()), tradeOrder.security());
        int filled = position.getQuantity();
        return Optional.of(createCancelledOrder(tradeOrder, filled));
      }
    }
    return Optional.empty();
  }

  @Validate(desired = traderx.morphir.rulesengine.models
                          .DesiredAction$DesiredAction$CANCELTRADE$.class)
  public void
  cancelTrade(TradeOrder order) {
    log.warn("Cancelling trade");

    if(!queue.remove(order)) {
      log.error("Could not find trade to cancel");
      return;
    }

    Trade t = tradeRepository.findByAccountId(order.accountId())
                  .stream()
                  .findFirst()
                  .orElse(null);

    t.setUpdated(new Date());
    t.setState(TradeState.Cancelled());

    tradeRepository.save(t);
  }

  // event loop for orders
  @Scheduled(fixedDelay = 1500)
  public void processQueue() {
    if (queue.isEmpty())
      return;

    final TradeOrder order = queue.poll();
    Trade t = tradeRepository.findByAccountId(order.accountId())
                  .stream()
                  .filter(trade -> trade.getSecurity() == order.security())
                  .findFirst()
                  .orElseThrow();
    Position position = positionRepository.findByAccountIdAndSecurity(
        Integer.valueOf(order.accountId()), order.security());

    int newQuantity =
      ((order.side() == TradeSide.BUY()) ? 1 : -1) * t.getQuantity();
    position.setQuantity(position.getQuantity() + newQuantity);

    t.setUpdated(new Date());
    t.setState(TradeState.Settled());

    simulateProcessing();

    tradeRepository.save(t);
    positionRepository.save(position);

    TradeBookingResult result = new TradeBookingResult(t, position);
    log.info("Trade Processing complete : " + result);

    // publish trade
    try {
      log.info("Publishing : " + result);
      publish(position, t, order.accountId());
    } catch (PubSubException exc) {
      log.error("Error publishing trade " + order, exc);
    }
  }
}
