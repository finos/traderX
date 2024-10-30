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
@RequestMapping(value="/health", produces="application/json")
public class HealthController {

	@Autowired
	PositionService positionService;
 

	@GetMapping("/ready")
	public ResponseEntity isReady() {
		List<Position> retVal = this.positionService.getAllPositions();		
		return ResponseEntity.ok(retVal.size()>0);
	}

	@GetMapping("/alive")
	public ResponseEntity<Boolean> isAlive() {
		return ResponseEntity.ok(true);
	}


	@ExceptionHandler(Exception.class)
	public ResponseEntity<String> generalError(Exception e) {
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
	}
}
