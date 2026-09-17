package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.service.PositionService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/health", produces = "application/json")
public class HealthController {

  private final PositionService positionService;

  public HealthController(PositionService positionService) {
    this.positionService = positionService;
  }

  @GetMapping("/ready")
  public ResponseEntity<Boolean> isReady() {
    return ResponseEntity.ok(positionService.getAllPositions().size() > 0);
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
