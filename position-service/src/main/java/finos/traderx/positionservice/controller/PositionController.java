package finos.traderx.positionservice.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.service.PositionService;

@CrossOrigin("*")
@RestController
@RequestMapping(value="/positions", produces="application/json")
public class PositionController {

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


	@ExceptionHandler(Exception.class)
	public ResponseEntity<String> generalError(Exception e) {
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
	}
}
