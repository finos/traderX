package finos.traderx.tradeprocessor.controller;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.tradeprocessor.model.*;
import finos.traderx.tradeprocessor.service.TradeService;
import io.swagger.models.Response;

@CrossOrigin("*")
@RestController
@RequestMapping("/tradeservice")
public class TradeServiceController {

	private static final Logger log = LoggerFactory.getLogger(TradeServiceController.class);

	@Autowired
	TradeService tradeService;
 

	@PostMapping("/order")
	public ResponseEntity<TradeBookingResult> processOrder(@RequestBody TradeOrder order) {
		TradeBookingResult result= tradeService.processTrade(order);
		return ResponseEntity.ok(result);
	}

	

}
