package finos.traderx.ordermatcher.config;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.ordermatcher.api.OrderResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
    @Bean
    @ConditionalOnProperty(name = "order.matcher.publisher", havingValue = "nats", matchIfMissing = true)
    public Publisher<OrderResponse> natsOrderPublisher(
        @Value("${nats.address:nats://${NATS_BROKER_HOST:localhost}:4222}") String natsAddress
    ) {
        NatsJSONPublisher<OrderResponse> publisher = new NatsJSONPublisher<>();
        publisher.setServerAddress(natsAddress);
        publisher.setSender("order-matcher");
        return publisher;
    }

    @Bean
    @ConditionalOnProperty(name = "order.matcher.publisher", havingValue = "noop")
    public Publisher<OrderResponse> noopOrderPublisher() {
        return new Publisher<>() {
            @Override
            public void publish(OrderResponse message) throws PubSubException {}

            @Override
            public void publish(String topic, OrderResponse message) throws PubSubException {}

            @Override
            public boolean isConnected() {
                return true;
            }

            @Override
            public void connect() throws PubSubException {}

            @Override
            public void disconnect() throws PubSubException {}
        };
    }
}
