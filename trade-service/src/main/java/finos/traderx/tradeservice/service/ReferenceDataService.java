package finos.traderx.tradeservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.tradeservice.model.Security;

@Service
public class ReferenceDataService {
    private static final Logger log = LoggerFactory.getLogger(ReferenceDataService.class);

    @Value("${reference.data.service.url}")
    private String referenceDataServiceAddress;

    private final RestTemplate restTemplate = new RestTemplate();

    public boolean validateTicker(String ticker) {
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
}
