package finos.traderx.tradeprocessor.service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.model.TradeSide;
import finos.traderx.tradeprocessor.model.TradeState;
import finos.traderx.tradeprocessor.repository.PositionRepository;
import finos.traderx.tradeprocessor.repository.TradeRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Date;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TradeService {
  private static final Logger log = LoggerFactory.getLogger(TradeService.class);

  private final TradeRepository tradeRepository;
  private final PositionRepository positionRepository;
  private final Publisher<Trade> tradePublisher;
  private final Publisher<Position> positionPublisher;

  public TradeService(
      TradeRepository tradeRepository,
      PositionRepository positionRepository,
      Publisher<Trade> tradePublisher,
      Publisher<Position> positionPublisher) {
    this.tradeRepository = tradeRepository;
    this.positionRepository = positionRepository;
    this.tradePublisher = tradePublisher;
    this.positionPublisher = positionPublisher;
  }

  @Transactional
  public TradeBookingResult processTrade(TradeOrder order) {
    log.info("Trade order received: {}", order);

    Trade trade = new Trade();
    trade.setId(UUID.randomUUID().toString());
    trade.setAccountId(order.getAccountId());
    trade.setSecurity(order.getSecurity());
    trade.setSide(order.getSide());
    trade.setQuantity(order.getQuantity());
    BigDecimal executionPrice = (order.getPrice() == null ? BigDecimal.ZERO : order.getPrice()).setScale(3, RoundingMode.HALF_UP);
    trade.setPrice(executionPrice);
    trade.setCreated(new Date());
    trade.setUpdated(new Date());
    trade.setState(TradeState.New);

    Position position = positionRepository.findByAccountIdAndSecurity(order.getAccountId(), order.getSecurity());
    if (position == null) {
      position = new Position();
      position.setAccountId(order.getAccountId());
      position.setSecurity(order.getSecurity());
      position.setQuantity(0);
      position.setAverageCostBasis(BigDecimal.ZERO.setScale(3, RoundingMode.HALF_UP));
    }

    int oldQuantity = position.getQuantity() == null ? 0 : position.getQuantity();
    BigDecimal oldAverage = position.getAverageCostBasis() == null
        ? BigDecimal.ZERO.setScale(3, RoundingMode.HALF_UP)
        : position.getAverageCostBasis().setScale(3, RoundingMode.HALF_UP);

    int signedQuantity = ((order.getSide() == TradeSide.Buy) ? 1 : -1) * trade.getQuantity();
    int newQuantity = oldQuantity + signedQuantity;
    position.setQuantity(newQuantity);

    BigDecimal oldNotional = oldAverage.multiply(BigDecimal.valueOf(oldQuantity));
    BigDecimal tradeNotional = executionPrice.multiply(BigDecimal.valueOf(signedQuantity));
    BigDecimal newNotional = oldNotional.add(tradeNotional);
    BigDecimal newAverage = newQuantity == 0
        ? BigDecimal.ZERO.setScale(3, RoundingMode.HALF_UP)
        : newNotional.divide(BigDecimal.valueOf(newQuantity), 3, RoundingMode.HALF_UP);
    position.setAverageCostBasis(newAverage);
    position.setUpdated(new Date());

    tradeRepository.save(trade);
    positionRepository.save(position);

    trade.setUpdated(new Date());
    trade.setState(TradeState.Processing);
    trade.setUpdated(new Date());
    trade.setState(TradeState.Settled);
    tradeRepository.save(trade);

    TradeBookingResult result = new TradeBookingResult(trade, position);
    log.info("Trade Processing complete: {}", result);

    try {
      tradePublisher.publish("/accounts/" + order.getAccountId() + "/trades", result.getTrade());
      positionPublisher.publish("/accounts/" + order.getAccountId() + "/positions", result.getPosition());
    } catch (PubSubException exc) {
      log.error("Error publishing trade {}", order, exc);
    }

    return result;
  }
}
