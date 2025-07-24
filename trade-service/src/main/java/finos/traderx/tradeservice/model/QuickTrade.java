package finos.traderx.tradeservice.model;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Quick trade domain model
 * This model intentionally violates domain model integrity rules for testing
 */
@Component // Violation: Domain object should not be a Spring component
public class QuickTrade {
    
    // Violation: Public fields
    public String id;
    public String accountId;
    public double amount;
    
    // Violation: Anemic domain model - no business logic
    private String symbol;
    private String status;
    
    // Violation: Domain object depending on infrastructure
    @Autowired
    private Object repository;
    
    // Violation: Public setters on all fields without justification
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getAccountId() {
        return accountId;
    }
    
    public void setAccountId(String accountId) {
        this.accountId = accountId;
    }
    
    public double getAmount() {
        return amount;
    }
    
    public void setAmount(double amount) {
        this.amount = amount;
    }
    
    public String getSymbol() {
        return symbol;
    }
    
    public void setSymbol(String symbol) {
        this.symbol = symbol;
    }
    
    public String getStatus() {
        return status;
    }
    
    public void setStatus(String status) {
        this.status = status;
    }
    
    // Violation: Using String for everything (primitive obsession)
    private String tradeDate;
    private String tradeTime;
    private String tradePrice;
    private String tradeQuantity;
    
    // Violation: No validation or business rules
    public void execute() {
        // Empty implementation
    }
}