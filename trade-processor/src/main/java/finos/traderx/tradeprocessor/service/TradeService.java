package finos.traderx.tradeprocessor.service;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.*;
import finos.traderx.tradeprocessor.repository.*;

@Service
public class TradeService {
	Logger log= LoggerFactory.getLogger(TradeService.class);
	@Autowired
	TradeRepository tradeRepository;

	@Autowired
	PositionRepository positionRepository;

	
    @Autowired 
    private Publisher<Trade> tradePublisher;
    
    @Autowired
    private Publisher<Position> positionPublisher;
    
	public TradeBookingResult processTrade(TradeOrder order) {
		log.info("Trade order received : "+order);
        Trade t=new Trade();
        t.setAccountId(order.getAccountID());

		log.info("Setting a random TradeID");
		t.setId(UUID.randomUUID().toString());


        t.setCreated(new Date());
        t.setUpdated(new Date());
        t.setSecurity(order.getSecurity());
        t.setSide(order.getSide());
        t.setQuantity(order.getQuantity());
		t.setState(TradeState.New);
		Position position=positionRepository.findByAccountIdAndSecurity(order.getAccountID(), order.getSecurity());
		log.info("Position for "+order.getAccountID()+" "+order.getSecurity()+" is "+position);
		if(position==null) {
			log.info("Creating new position for "+order.getAccountID()+" "+order.getSecurity());
			position=new Position();
			position.setAccountId(order.getAccountID());
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
			tradePublisher.publish("/accounts/"+order.getAccountID()+"/trades", result.getTrade());
			positionPublisher.publish("/accounts/"+order.getAccountID()+"/positions", result.getPosition());
		} catch (PubSubException exc){
			log.error("Error publishing trade "+order,exc);
		}
		
		return result;	
	}

}
