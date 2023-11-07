package finos.traderx.tradeservice.controller;

//import dist.traderx.models.TradeOrder;
import dist.traderx.models.TradeOrder.TradeOrder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
//import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.service.TradeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
//import org.example.*;

@CrossOrigin("*")
@RestController
@RequestMapping(value="/trade", produces = "application/json")
public class TradeOrderController {

	private static final Logger log = LoggerFactory.getLogger(TradeOrderController.class);

	private Publisher<TradeOrder> tradePublisher;

	private TradeService tradeService;

	public TradeOrderController(TradeService tradeService, Publisher<TradeOrder> tradePublisher){
		this.tradeService = tradeService;
		this.tradePublisher = tradePublisher;
	}

	@Operation(description = "Submit a new trade order")
	@PostMapping("/")
	public ResponseEntity<TradeOrder> createTradeOrder(@Parameter(description = "the intendeded trade order") @RequestBody TradeOrder tradeOrder) {
		log.info("Called createTradeOrder");


		if (!tradeService.validateTicker(tradeOrder.security())
		{
			throw new ResourceNotFoundException(tradeOrder.getSecurity() + " not found in Reference data service.");
		}
		else if(!tradeService.validateAccount(tradeOrder.getAccountId()))
		{
			throw new ResourceNotFoundException(tradeOrder.getAccountId() + " not found in Account service.");
		}
		else
		{
			try{
				log.info("Trade is valid. Submitting {}", tradeOrder);
				tradePublisher.publish("/trades",tradeOrder);
				return  ResponseEntity.ok(tradeOrder);
			}  catch (Exception e){
				throw new RuntimeException("Failed to publish trade order", e);
			}
		}
	}
}