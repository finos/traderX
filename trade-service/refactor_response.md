
I'll help you refactor this code following SOLID principles and Inversion of Control. We'll create a dedicated account validation service and use dependency injection.



```java
package finos.traderx.tradeservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import finos.traderx.tradeservice.model.Account;

public interface AccountValidationService {
    boolean validateAccount(Integer id);
}

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
            log.info("Validate account {}", response.getBody());
            return true;
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

@Configuration
public class AccountServiceConfig {
    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}

// Updated TradeOrderController
@RestController
@RequestMapping(value="/trade", produces = "application/json")
public class TradeOrderController {
    private final AccountValidationService accountValidationService;
    
    @Autowired
    public TradeOrderController(AccountValidationService accountValidationService) {
        this.accountValidationService = accountValidationService;
    }
    
    // Other methods...
    
    private boolean validateAccount(Integer id) {
        return accountValidationService.validateAccount(id);
    }
}
```


This refactoring implements several SOLID principles:

1. Single Responsibility Principle (SRP):
    - Separated account validation logic into its own service
    - Each class has one specific responsibility

2. Open/Closed Principle (OCP):
    - The `AccountValidationService` interface allows for different implementations
    - New validation strategies can be added without modifying existing code

3. Interface Segregation Principle (ISP):
    - Created a focused interface for account validation

4. Dependency Inversion Principle (DIP):
    - `TradeOrderController` depends on the `AccountValidationService` interface, not the implementation
    - Dependencies are injected through constructor injection

5. Liskov Substitution Principle (LSP):
    - Any implementation of `AccountValidationService` can be used without affecting the system's behavior

Key improvements:

1. Proper dependency injection using constructor injection
2. Separation of concerns with dedicated service class
3. Improved testability through interface-based design
4. Better error handling and logging
5. Configuration separated into its own class
6. Removed direct RestTemplate instantiation in favor of managed bean

You can now easily mock the `AccountValidationService` for testing and swap implementations if needed.
