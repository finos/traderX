package finos.traderx.tradeprocessor.controller;

import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.service.TradeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import traderx.morphir.rulesengine.models.TradeMetadata.TradeMetadata;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;
import traderx.morphir.rulesengine.models.TradeState;

@CrossOrigin("*")
@RestController
@RequestMapping("/tradeservice")
public class TradeServiceController {

  private static final Logger log =
      LoggerFactory.getLogger(TradeServiceController.class);

  @Autowired TradeService tradeService;

  @PostMapping("/order")
  public ResponseEntity<TradeBookingResult>
  processOrder(@RequestBody TradeOrder order) {

    TradeMetadata metadata = new TradeMetadata(1, TradeState.New());
    TradeBookingResult result = tradeService.makeNewTrade(order, metadata);
    return ResponseEntity.ok(result);
  }

  @PostMapping("/cancel")
  public ResponseEntity<String> cancelOrder(@RequestBody TradeOrder order) {

    tradeService.cancelTrade(order);
    return ResponseEntity.ok("complete");
  }
}
