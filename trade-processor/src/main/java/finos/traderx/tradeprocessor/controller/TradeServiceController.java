package finos.traderx.tradeprocessor.controller;

import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.service.TradeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;

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

    TradeBookingResult result = tradeService.makeNewTrade(order);
    return ResponseEntity.ok(result);
  }
}
