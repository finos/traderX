package finos.traderx.tradeservice;
import finos.traderx.tradeservice.model.*;
import finos.traderx.messaging.socketio.*;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import com.fasterxml.jackson.databind.ObjectMapper;

public class TradeServiceDemo extends SocketIOJSONPublisher<TradeOrder> {
    private static ObjectMapper objectMapper = new ObjectMapper();


    @Value("${trade.feed.url}")
	public static String tradeFeedAddress="http://localhost:18086";

    static String tradeFeedUrl;
    public static void main(String[] args ) throws Throwable {
        SocketIOJSONSubscriber<TradeOrder>  sub=new SocketIOJSONSubscriber<TradeOrder>(TradeOrder.class){
            org.slf4j.Logger log=LoggerFactory.getLogger(TradeServiceDemo.class);
            @Override
            public void onMessage(TradeOrder order){
                try{
                    log.info("INCOMING TRADE ORDER {}",objectMapper.writeValueAsString(order));
                } catch (Exception x){
                    log.error("Error printing order",x);
                }
            }
        };
        sub.setSocketAddress(tradeFeedAddress);
        sub.connect();
        Thread.sleep(2500);

        sub.subscribe("/orders");
        Thread.sleep(2500);

        TradeServiceDemo p=new TradeServiceDemo();
        p.setSocketAddress(tradeFeedAddress);
        p.setTopic("/orders");
        p.afterPropertiesSet();
        Thread.sleep(2500);
        TradeOrder order = new TradeOrder("00ss0022kdsdnsdd", 123333,"IBM", TradeSide.Sell, 1000);
        p.publish(order);

    }
}
