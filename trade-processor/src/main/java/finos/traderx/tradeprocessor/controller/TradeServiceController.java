package finos.traderx.tradeprocessor.controller;

import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/tradeservice")
public class TradeServiceController {

  private final TradeService tradeService;

  public TradeServiceController(TradeService tradeService) {
    this.tradeService = tradeService;
  }

  @PostMapping("/order")
  public ResponseEntity<TradeBookingResult> processOrder(@RequestBody TradeOrder order) {
    TradeBookingResult result = tradeService.processTrade(order);
    return ResponseEntity.ok(result);
  }
}
