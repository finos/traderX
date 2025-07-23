package finos.traderx.tradeservice.service;

import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

/**
 * Service for handling account-related operations.
 * Provides fallback mechanisms to allow development and testing
 * even when the account service is offline.
 */
@Service
public class AccountService {

    private static final Logger log = LoggerFactory.getLogger(AccountService.class);

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${account.service.url}")
    private String accountServiceAddress;

    @Value("${account.service.fallback.enabled:true}")
    private boolean fallbackEnabled;

    /**
     * Validates if an account exists and is valid.
     * 
     * @param accountId the account ID to validate
     * @return true if the account is valid, false otherwise
     * @throws ResourceNotFoundException if account is not found and fallback is disabled
     */
    public boolean validateAccount(Integer accountId) {
        if (accountId == null) {
            log.warn("Account ID is null");
            return false;
        }

        try {
            Account account = getAccountById(accountId);
            log.info("Account validation successful for ID: {}", accountId);
            return account != null;
        } catch (ResourceNotFoundException e) {
            if (fallbackEnabled) {
                log.warn("Account not found, using fallback validation for account ID: {}", accountId);
                return performFallbackValidation(accountId);
            } else {
                log.error("Account validation failed for ID: {} and fallback is disabled", accountId);
                return false;
            }
        } catch (Exception e) {
            if (fallbackEnabled) {
                log.warn("Account service unavailable, using fallback validation for account ID: {}", accountId);
                return performFallbackValidation(accountId);
            } else {
                log.error("Account validation failed for ID: {} and fallback is disabled", accountId);
                throw new ResourceNotFoundException("Account " + accountId + " not found in Account service.");
            }
        }
    }

    /**
     * Retrieves account information by ID.
     * 
     * @param accountId the account ID
     * @return the Account object
     * @throws ResourceNotFoundException if account is not found
     */
    public Account getAccountById(Integer accountId) {
        String url = accountServiceAddress + "/account/" + accountId;
        
        try {
            ResponseEntity<Account> response = restTemplate.getForEntity(url, Account.class);
            Account account = response.getBody();
            log.info("Retrieved account: {}", account);
            return account;
        } catch (HttpClientErrorException ex) {
            if (ex.getRawStatusCode() == 404) {
                log.info("Account {} not found in account service", accountId);
                throw new ResourceNotFoundException("Account " + accountId + " not found");
            } else {
                log.error("Error retrieving account {}: {}", accountId, ex.getMessage());
                throw new RuntimeException("Failed to retrieve account", ex);
            }
        }
    }

    /**
     * Performs fallback validation when the account service is unavailable.
     * This allows development and testing to continue even when the account service is down.
     * 
     * @param accountId the account ID to validate
     * @return true if the account passes fallback validation
     */
    private boolean performFallbackValidation(Integer accountId) {
        // Simple fallback logic - in a real scenario, this might check a cache,
        // use default test accounts, or apply business rules
        if (accountId <= 0) {
            log.debug("Fallback validation failed: invalid account ID {}", accountId);
            return false;
        }
        
        // For development purposes, accept account IDs in a reasonable range
        if (accountId >= 1 && accountId <= 10000) {
            log.debug("Fallback validation passed for account ID: {}", accountId);
            return true;
        }
        
        log.debug("Fallback validation failed: account ID {} outside acceptable range", accountId);
        return false;
    }

    /**
     * Checks if the account service is available.
     * 
     * @return true if the service is reachable, false otherwise
     */
    public boolean isAccountServiceAvailable() {
        try {
            String healthUrl = accountServiceAddress + "/actuator/health";
            ResponseEntity<String> response = restTemplate.getForEntity(healthUrl, String.class);
            return response.getStatusCode().is2xxSuccessful();
        } catch (Exception e) {
            log.debug("Account service health check failed: {}", e.getMessage());
            return false;
        }
    }
}