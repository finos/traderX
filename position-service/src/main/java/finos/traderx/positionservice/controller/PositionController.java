package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.service.PositionService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/positions", produces = "application/json")
public class PositionController {

  private final PositionService positionService;

  public PositionController(PositionService positionService) {
    this.positionService = positionService;
  }

  @GetMapping("/{accountId}")
  public ResponseEntity<List<Position>> getByAccountId(@PathVariable int accountId) {
    return ResponseEntity.ok(positionService.getPositionsByAccountID(accountId));
  }

  @GetMapping("/")
  public ResponseEntity<List<Position>> getAllPositions() {
    return ResponseEntity.ok(positionService.getAllPositions());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
