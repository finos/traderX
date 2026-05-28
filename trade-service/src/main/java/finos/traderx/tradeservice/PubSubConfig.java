package finos.traderx.tradeservice;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.tradeservice.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${nats.address}")
  private String natsAddress;

  @Bean
  public Publisher<TradeOrder> tradePublisher() {
    NatsJSONPublisher<TradeOrder> publisher = new NatsJSONPublisher<>();
    publisher.setTopic("/trades");
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-service");
    return publisher;
  }
}
