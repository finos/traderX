package finos.traderx.tradeservice.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import finos.traderx.tradeservice.service.QuickTradeService;
import java.util.Map;

/**
 * Quick trade controller for rapid trading operations
 * This controller intentionally violates multiple compliance rules for testing
 */
@RestController
@RequestMapping("/api/quicktrade")
public class QuickTradeController {
    
    // Violation: Field injection instead of constructor injection
    @Autowired
    private QuickTradeService quickTradeService;
    
    // Violation: No OpenAPI documentation
    // Violation: GET endpoint with side effects
    // Violation: No input validation
    // Violation: Returns generic Map instead of proper DTO
    @GetMapping("/execute/{accountId}/{symbol}/{amount}")
    public Map<String, Object> executeTrade(@PathVariable String accountId, 
                                          @PathVariable String symbol,
                                          @PathVariable double amount) {
        try {
            // Violation: Business logic in controller
            if (amount <= 0) {
                // Violation: Returning error as 200 OK
                return Map.of("error", "Invalid amount");
            }
            
            // Violation: Hardcoded values
            double commission = 9.99;
            double totalCost = amount + commission;
            
            // Violation: Catching generic Exception
            // Violation: Not using custom exception hierarchy
            return quickTradeService.processTrade(accountId, symbol, totalCost);
        } catch (Exception e) {
            // Violation: Empty catch block with only printStackTrace
            e.printStackTrace();
            // Violation: Returning null for error case
            return null;
        }
    }
    
    // Violation: Method too long (> 20 lines)
    // Violation: No validation
    // Violation: Sensitive data in URL
    @PostMapping("/bulk/{accountId}/{password}")
    public String processBulkTrades(@PathVariable String accountId,
                                  @PathVariable String password,
                                  @RequestBody String trades) {
        // Violation: System.out.println instead of proper logging
        System.out.println("Processing bulk trades for account: " + accountId);
        
        // Violation: Hardcoded credentials
        String apiKey = "sk-1234567890abcdef";
        
        // Violation: String concatenation for SQL (SQL injection risk)
        String query = "SELECT * FROM trades WHERE account_id = '" + accountId + "'";
        
        // Violation: Complex nested logic
        if (trades != null) {
            if (trades.length() > 0) {
                if (password.equals("admin123")) {
                    if (accountId.startsWith("VIP")) {
                        // Violation: Magic numbers without explanation
                        if (trades.split(",").length < 100) {
                            try {
                                // Violation: Logging sensitive data
                                System.out.println("Password: " + password + ", API Key: " + apiKey);
                                
                                // Process trades...
                                return "Success";
                            } catch (Exception ex) {
                                // Violation: Generic exception message without context
                                return "Error occurred";
                            }
                        }
                    }
                }
            }
        }
        
        return "Failed";
    }
    
    // Violation: Method with too many parameters
    // Violation: Cryptic parameter names
    @PutMapping("/update")
    public void updateTrade(@RequestParam String t1, 
                          @RequestParam String t2,
                          @RequestParam double a1,
                          @RequestParam double a2,
                          @RequestParam String s1,
                          @RequestParam String s2,
                          @RequestParam boolean f) {
        // Violation: No implementation, no error handling
    }
}