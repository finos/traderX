package finos.traderx.tradeservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.tradeservice.model.Account;

@Service
public class AccountValidationServiceImpl implements AccountValidationService {
    private static final Logger log = LoggerFactory.getLogger(AccountValidationServiceImpl.class);

    private final RestTemplate restTemplate;
    private final String accountServiceAddress;

    public AccountValidationServiceImpl(
            RestTemplate restTemplate,
            @Value("${account.service.url}") String accountServiceAddress) {
        this.restTemplate = restTemplate;
        this.accountServiceAddress = accountServiceAddress;
    }

    @Override
    public boolean validateAccount(Integer id) {
        String url = this.accountServiceAddress + "/account/" + id;

        try {
            ResponseEntity<Account> response = this.restTemplate.getForEntity(url, Account.class);
            if (response == null){
                log.error("Response is null for account id: {}", id);
                return false;
            }
            else {
                log.info("Validate account {}", response.getBody());
                return true;
            }
        } catch (HttpClientErrorException ex) {
            if (ex.getRawStatusCode() == 404) {
                log.info("Account {} not found in account service.", id);
            } else {
                log.error("Error validating account: {}", ex.getMessage());
            }
            return false;
        }
    }
}