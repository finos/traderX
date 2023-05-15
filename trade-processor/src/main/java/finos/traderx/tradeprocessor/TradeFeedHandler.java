package finos.traderx.tradeprocessor;

import org.springframework.beans.factory.annotation.Autowired;

import finos.traderx.messaging.socketio.SocketIOJSONSubscriber;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;

public class TradeFeedHandler extends SocketIOJSONSubscriber<TradeOrder> {
    static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(TradeFeedHandler.class);

    public TradeFeedHandler(){
        super(TradeOrder.class);
    }
    @Autowired
    private TradeService tradeService;

    @Override
    public void onMessage(TradeOrder order) {
        try{
            tradeService.processTrade(order);
        } catch (Exception x){
            log.error("Error handling incoming trade order {}",order,x);
        }
       
    }
    
}
