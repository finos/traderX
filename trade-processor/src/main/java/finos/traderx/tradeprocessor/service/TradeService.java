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
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;
import traderx.morphir.rulesengine.models.TradeSide;

@Service
public class TradeService {
  Logger log = LoggerFactory.getLogger(TradeService.class);

  @Autowired TradeRepository tradeRepository;

  @Autowired PositionRepository positionRepository;

  @Autowired private Publisher<Trade> tradePublisher;

  @Autowired private Publisher<Position> positionPublisher;

  @Validate(attempt = traderx.morphir.rulesengine.models
                          .TradeState$TradeState$New$.class)
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
    // t.setState(TradeState.New);

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

    int newQuantity =
        ((order.side() == TradeSide.BUY()) ? 1 : -1) * t.getQuantity();
    position.setQuantity(position.getQuantity() + newQuantity);

    log.info("Trade {}", t);
    tradeRepository.save(t);
    positionRepository.save(position);

    // Simulate the handling of this trade...
    // Now mark as processing
    t.setUpdated(new Date());
    // t.setState(TradeState.Processing);

    // Now mark as settled
    t.setUpdated(new Date());
    // t.setState(TradeState.Settled);
    tradeRepository.save(t);

    TradeBookingResult result = new TradeBookingResult(t, position);
    log.info("Trade Processing complete : " + result);

    try {
      log.info("Publishing : " + result);
      tradePublisher.publish("/accounts/" + order.accountId() + "/trades",
                             result.getTrade());
      positionPublisher.publish("/accounts/" + order.accountId() + "/positions",
                                result.getPosition());
    } catch (PubSubException exc) {
      log.error("Error publishing trade " + order, exc);
    }

    return result;
  }

  @Validate(attempt = traderx.morphir.rulesengine.models
                          .TradeState$TradeState$Cancelled$.class)
  public void
  cancelTrade(String orderId) {
    log.warn("Cancelling trade");
  }
}
