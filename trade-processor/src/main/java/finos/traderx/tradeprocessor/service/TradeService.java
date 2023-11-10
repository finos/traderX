package finos.traderx.tradeprocessor.service;

import java.util.Date;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.*;
import finos.traderx.tradeprocessor.repository.*;

@Service
public class TradeService {
	Logger log= LoggerFactory.getLogger(TradeService.class);

	TradeRepository tradeRepository;

	PositionRepository positionRepository;

    private final Publisher<Trade> tradePublisher;

    private final Publisher<Position> positionPublisher;

	public TradeService(TradeRepository tradeRepository, PositionRepository positionRepository, Publisher<Trade> tradePublisher, Publisher<Position> positionPublisher) {
		this.tradeRepository = tradeRepository;
		this.positionRepository = positionRepository;
		this.tradePublisher = tradePublisher;
		this.positionPublisher = positionPublisher;
	}
    
	public TradeBookingResult processTrade(TradeOrder order) {
		log.info("Trade order received : "+order);
        Trade t=new Trade();
        t.setAccountId(order.getAccountId());

		log.info("Setting a random TradeID");
		t.setId(UUID.randomUUID().toString());


        t.setCreated(new Date());
        t.setUpdated(new Date());
        t.setSecurity(order.getSecurity());
        t.setSide(order.getSide());
        t.setQuantity(order.getQuantity());
		t.setState(TradeState.New);
		Position position=positionRepository.findByAccountIdAndSecurity(order.getAccountId(), order.getSecurity());
		log.info("Position for "+order.getAccountId()+" "+order.getSecurity()+" is "+position);
		if(position==null) {
			log.info("Creating new position for "+order.getAccountId()+" "+order.getSecurity());
			position=new Position();
			position.setAccountId(order.getAccountId());
			position.setSecurity(order.getSecurity());
			position.setQuantity(0);
		}
		int newQuantity=((order.getSide()==TradeSide.Buy)?1:-1)*t.getQuantity();
		position.setQuantity(position.getQuantity()+newQuantity);
		log.info("Trade {}",t);
		tradeRepository.save(t);
		positionRepository.save(position);
		// Simulate the handling of this trade...
		// Now mark as processing
		t.setUpdated(new Date());
		t.setState(TradeState.Processing);
		// Now mark as settled
		t.setUpdated(new Date());
		t.setState(TradeState.Settled);
		tradeRepository.save(t);
		

		TradeBookingResult result=new TradeBookingResult(t, position);
		log.info("Trade Processing complete : "+result);
		try{
			log.info("Publishing : "+result);
			tradePublisher.publish("/accounts/"+order.getAccountId()+"/trades", result.getTrade());
			positionPublisher.publish("/accounts/"+order.getAccountId()+"/positions", result.getPosition());
		} catch (PubSubException exc){
			log.error("Error publishing trade "+order,exc);
		}
		
		return result;	
	}

}
