package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.model.Trade;
import finos.traderx.positionservice.service.TradeService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/trades", produces = "application/json")
public class TradeController {

  private final TradeService tradeService;

  public TradeController(TradeService tradeService) {
    this.tradeService = tradeService;
  }

  @GetMapping("/{accountId}")
  public ResponseEntity<List<Trade>> getByAccountId(@PathVariable int accountId) {
    return ResponseEntity.ok(tradeService.getTradesByAccountID(accountId));
  }

  @GetMapping("/")
  public ResponseEntity<List<Trade>> getAllTrades() {
    return ResponseEntity.ok(tradeService.getAllTrades());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
