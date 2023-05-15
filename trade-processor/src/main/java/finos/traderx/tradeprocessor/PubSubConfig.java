package finos.traderx.tradeprocessor;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.socketio.SocketIOJSONPublisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeOrder;

@Configuration
public class PubSubConfig {
    @Value("${trade.feed.address}")
    private String tradeFeedAddress;

    @Bean 
    public Publisher<Position> positionPublisher() {
        SocketIOJSONPublisher<Position> publisher = new SocketIOJSONPublisher<Position>(){};
        publisher.setSocketAddress(tradeFeedAddress);
        return publisher;
    }

    @Bean 
    public Publisher<Trade> tradePublisher() {
        SocketIOJSONPublisher<Trade> publisher = new SocketIOJSONPublisher<Trade>(){};
        publisher.setSocketAddress(tradeFeedAddress);
        return publisher;
    }

    
    @Bean 
    public Subscriber<TradeOrder> tradeFeedHandler() {
        TradeFeedHandler handler=new TradeFeedHandler();
        handler.setDefaultTopic("/trades");
        handler.setSocketAddress(tradeFeedAddress);
        return handler;
    }
}
