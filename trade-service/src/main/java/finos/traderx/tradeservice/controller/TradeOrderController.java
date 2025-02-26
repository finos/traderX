package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.service.AccountValidationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@CrossOrigin("*")
@RestController
@RequestMapping(value = "/trade", produces = "application/json")
public class TradeOrderController {

    private static final Logger log = LoggerFactory.getLogger(TradeOrderController.class);

    private final AccountValidationService accountValidationService;
    @Autowired
    private Publisher<TradeOrder> tradePublisher;
    private final RestTemplate restTemplate = new RestTemplate();
    @Value("${reference.data.service.url}")
    private String referenceDataServiceAddress;
    @Value("${account.service.url}")
    private String accountServiceAddress;

    @Autowired
    public TradeOrderController(AccountValidationService accountValidationService) {
        this.accountValidationService = accountValidationService;
    }

    @Operation(description = "Submit a new trade order")
    @PostMapping("/")
    public ResponseEntity<TradeOrder> createTradeOrder(@Parameter(description = "the intendeded trade order") @RequestBody TradeOrder tradeOrder) {
        log.info("Called createTradeOrder");

        if (!validateTicker(tradeOrder.getSecurity())) {
            throw new ResourceNotFoundException(tradeOrder.getSecurity() + " not found in Reference data service.");
        } else if (!validateAccount(tradeOrder.getAccountId())) {
            throw new ResourceNotFoundException(tradeOrder.getAccountId() + " not found in Account service.");
        } else {
            try {
                log.info("Trade is valid. Submitting {}", tradeOrder);
                tradePublisher.publish("/trades", tradeOrder);
                return ResponseEntity.ok(tradeOrder);
            } catch (PubSubException e) {
                throw new RuntimeException("Failed to publish trade order", e);
            }
        }
    }

    private boolean validateTicker(String ticker) {
        // Move whole method to a sperate class that handles all reference data
        // so we can mock it and run without this service up.
        String url = this.referenceDataServiceAddress + "//stocks/" + ticker;
        ResponseEntity<Security> response = null;

        try {
            response = this.restTemplate.getForEntity(url, Security.class);
            log.info("Validate ticker " + response.getBody().toString());
            return true;
        } catch (HttpClientErrorException ex) {
            if (ex.getRawStatusCode() == 404) {
                log.info(ticker + " not found in reference data service.");
            } else {
                log.error(ex.getMessage());
            }
            return false;
        }
    }

    private boolean validateAccount(Integer id) {
        return accountValidationService.validateAccount(id);
    }
}