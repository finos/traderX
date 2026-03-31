package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${nats.address}")
  private String natsAddress;

  @Bean
  public Publisher<Position> positionPublisher() {
    NatsJSONPublisher<Position> publisher = new NatsJSONPublisher<>();
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-processor");
    return publisher;
  }

  @Bean
  public Publisher<Trade> tradePublisher() {
    NatsJSONPublisher<Trade> publisher = new NatsJSONPublisher<>();
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-processor");
    return publisher;
  }

  @Bean
  public Subscriber<TradeOrder> tradeFeedHandler() {
    TradeFeedHandler handler = new TradeFeedHandler();
    handler.setDefaultTopic("/trades");
    handler.setServerAddress(natsAddress);
    return handler;
  }
}
