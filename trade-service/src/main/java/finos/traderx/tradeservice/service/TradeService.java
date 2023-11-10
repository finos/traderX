package finos.traderx.tradeservice.service;

import finos.traderx.tradeservice.controller.TradeOrderController;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@Service
public class TradeService {
    private static final Logger log = LoggerFactory.getLogger(TradeOrderController.class);
    private final RestTemplate restTemplate = new RestTemplate();
    @Value("${reference.data.service.url}")
    private String referenceDataServiceAddress;
    @Value("${account.service.url}")
    private String accountServiceAddress;

    public boolean validateTicker(String ticker)
    {
        // Move whole method to a sperate class that handles all reference data
        // so we can mock it and run without this service up.
        String url = this.referenceDataServiceAddress + "//stocks/" + ticker;
        ResponseEntity<Security> response = null;

        try {
            response = this.restTemplate.getForEntity(url, Security.class);
            log.info("Validate ticker " + response.getBody().toString());
            return true;
        }
        catch (HttpClientErrorException ex) {
            if (ex.getRawStatusCode() == 404) {
                log.info(ticker + " not found in reference data service.");
            }
            else {
                log.error(ex.getMessage());
            }
            return false;
        }
    }

    public boolean validateAccount(Integer id)
    {
        // Move whole method to a sperate class that handles all accounts
        // so we can mock it and run without this service up.

        String url = this.accountServiceAddress + "//account/" + id;
        ResponseEntity<Account> response = null;

        try
        {
            response = this.restTemplate.getForEntity(url, Account.class);
            log.info("Validate account " + response.getBody().toString());
            return true;
        }
        catch (HttpClientErrorException ex) {
            if (ex.getRawStatusCode() == 404) {
                log.info("Account" + id + " not found in account service.");
            }
            else {
                log.error(ex.getMessage());
            }
            return false;
        }
    }
}
