package finos.traderx.positionservice.controller;

import java.util.List;

import finos.traderx.positionservice.model.*;
import finos.traderx.positionservice.service.PositionService;

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

@CrossOrigin("*")
@RestController
@RequestMapping("/positions")
public class PositionController {

	private static final Logger logger = LoggerFactory.getLogger(TradeController.class);

	private RestTemplate restTemplate = new RestTemplate();

	@Autowired
	PositionService positionService;
 

	@GetMapping("/{accountId}")
	public ResponseEntity<List<Position>> getByAccountId(@PathVariable int accountId) {
		List<Position> retVal = this.positionService.getPositionsByAccountID(accountId);
		return ResponseEntity.ok(retVal);
	}

	@GetMapping("/")
	public ResponseEntity<List<Position>> getAllPositions() {
		return ResponseEntity.ok(this.positionService.getAllPositions());
	}


	/*@ExceptionHandler(ResourceNotFoundException.class)
	public ResponseEntity<String> resourceNotFoundExceptionMapper(ResourceNotFoundException e) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
	}

	//@ExceptionHandler(Exception.class)
	public ResponseEntity<String> generalError(Exception e) {
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
	}*/
}
