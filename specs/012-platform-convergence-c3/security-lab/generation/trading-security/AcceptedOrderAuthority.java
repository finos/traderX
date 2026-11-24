package __PACKAGE__.security;

import __PACKAGE__.model.OrderRecord;
import __PACKAGE__.model.OrderStatus;
import java.math.BigDecimal;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Component;

/** Stored business authorization, not a bearer credential or a tamper-proof signature. */
@Component
public final class AcceptedOrderAuthority {
  private final TradingAccess access;
  private final String issuer;

  public AcceptedOrderAuthority(TradingAccess access, @Value("${lab.identity.issuer}") String issuer) {
    this.access = access;
    this.issuer = issuer;
  }

  public void accept(OrderRecord order) {
    access.requireTrade(order.getAccountId());
    String subject = access.subject();
    if (subject.length() > 255 || issuer.length() > 512 || !issuer.equals(access.issuer())) denied();
    order.setAcceptedSubject(subject);
    order.setAcceptedIssuer(issuer);
    order.setAcceptedTerms(terms(order));
  }

  public void requireEligible(OrderRecord order) {
    if (!issuer.equals(order.getAcceptedIssuer()) || order.getAcceptedTerms() == null
        || !order.getAcceptedTerms().equals(terms(order))
        || order.getCreatedAt() == null || order.getCreatedAt().isAfter(Instant.now())
        || !(order.getStatus() == OrderStatus.NEW || order.getStatus() == OrderStatus.PARTIALLY_FILLED)
        || order.getRemainingQuantity() == null || order.getRemainingQuantity() <= 0
        || order.getRemainingQuantity() > order.getQuantity()) denied();
    access.requireAcceptedTrader(order.getAcceptedSubject(), order.getAccountId());
  }

  private String terms(OrderRecord order) {
    if (order.getOrderId() == null || order.getAccountId() == null || order.getAccountId() <= 0
        || order.getSecurity() == null || !order.getSecurity().matches("[A-Z0-9.\\-]{1,16}")
        || order.getSide() == null || order.getQuantity() == null || order.getQuantity() <= 0
        || order.getLimitPrice() == null || order.getLimitPrice().compareTo(BigDecimal.ZERO) <= 0) denied();
    return String.join("|", order.getOrderId(), order.getAccountId().toString(), order.getSecurity(),
        order.getSide().name(), order.getQuantity().toString(), order.getLimitPrice().stripTrailingZeros().toPlainString());
  }

  private static void denied() { throw new AccessDeniedException("Order authority unavailable"); }
}
