package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.PriceQuote;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;
import java.math.BigDecimal;
import java.math.RoundingMode;

@RestController
@RequestMapping(value = "/trade", produces = "application/json")
public class TradeOrderController {

  private static final Logger log = LoggerFactory.getLogger(TradeOrderController.class);

  private final Publisher<TradeOrder> tradePublisher;
  private final RestTemplate restTemplate = new RestTemplate();

  @Value("${reference.data.service.url}")
  private String referenceDataServiceAddress;

  @Value("${account.service.url}")
  private String accountServiceAddress;

  @Value("${price.service.url}")
  private String priceServiceAddress;

  public TradeOrderController(Publisher<TradeOrder> tradePublisher) {
    this.tradePublisher = tradePublisher;
  }

  @Operation(description = "Submit a new trade order")
  @PostMapping("/")
  public ResponseEntity<TradeOrder> createTradeOrder(
      @Parameter(description = "the intended trade order") @RequestBody TradeOrder tradeOrder) {
    log.info("Called createTradeOrder");

    if (!validateTicker(tradeOrder.getSecurity())) {
      throw new ResourceNotFoundException(tradeOrder.getSecurity() + " not found in Reference data service.");
    } else if (!validateAccount(tradeOrder.getAccountId())) {
      throw new ResourceNotFoundException(tradeOrder.getAccountId() + " not found in Account service.");
    } else {
      try {
        BigDecimal executionPrice = fetchExecutionPrice(tradeOrder.getSecurity());
        tradeOrder.setPrice(executionPrice);
        log.info("Trade is valid. Submitting {}", tradeOrder);
        tradePublisher.publish("/trades", tradeOrder);
        return ResponseEntity.ok(tradeOrder);
      } catch (PubSubException e) {
        throw new RuntimeException("Failed to publish trade order", e);
      }
    }
  }

  private boolean validateTicker(String ticker) {
    String url = this.referenceDataServiceAddress + "/stocks/" + ticker;
    try {
      ResponseEntity<Security> response = this.restTemplate.getForEntity(url, Security.class);
      log.info("Validate ticker {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getRawStatusCode() == 404) {
        log.info("{} not found in reference data service.", ticker);
      } else {
        log.error(ex.getMessage(), ex);
      }
      return false;
    }
  }

  private boolean validateAccount(Integer id) {
    String url = this.accountServiceAddress + "/account/" + id;
    try {
      ResponseEntity<Account> response = this.restTemplate.getForEntity(url, Account.class);
      log.info("Validate account {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getRawStatusCode() == 404) {
        log.info("Account {} not found in account service.", id);
      } else {
        log.error(ex.getMessage(), ex);
      }
      return false;
    }
  }

  private BigDecimal fetchExecutionPrice(String ticker) {
    String url = this.priceServiceAddress + "/prices/" + ticker;
    try {
      ResponseEntity<PriceQuote> response = this.restTemplate.getForEntity(url, PriceQuote.class);
      PriceQuote quote = response.getBody();
      if (quote == null || quote.getPrice() == null) {
        throw new ResourceNotFoundException("Price quote missing for ticker " + ticker);
      }
      return quote.getPrice().setScale(3, RoundingMode.HALF_UP);
    } catch (HttpClientErrorException ex) {
      if (ex.getRawStatusCode() == 404) {
        throw new ResourceNotFoundException("Price quote unavailable for ticker " + ticker);
      }
      throw ex;
    }
  }
}
