package __PACKAGE__.security;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public final class TradingAccess {
  record Grant(String role, Set<Integer> accounts) {}
  private final Map<String, Grant> grants;

  public TradingAccess(@Value("${lab.identity.entitlements-file}") String filename) throws Exception {
    Path path = Path.of(filename);
    if (!path.isAbsolute()) throw new IllegalArgumentException("Absolute entitlement path required");
    grants = parse(Files.readString(path));
  }

  static Map<String, Grant> parse(String text) {
    Map<String, Grant> result = new HashMap<>();
    for (String raw : text.lines().toList()) {
      String line = raw.strip();
      if (line.isEmpty() || line.startsWith("#")) continue;
      String[] pair = line.split("=", 2);
      if (pair.length != 2 || pair[0].isBlank() || pair[0].chars().anyMatch(Character::isWhitespace))
        throw new IllegalArgumentException("Malformed subject mapping");
      String[] grant = pair[1].split(":", -1);
      if (grant.length != 2 || !Set.of("read-only", "trader", "operator").contains(grant[0]))
        throw new IllegalArgumentException("Malformed role mapping");
      Set<Integer> accounts = new HashSet<>();
      if (!grant[1].isEmpty()) for (String value : grant[1].split(",", -1)) {
        if (!value.matches("[1-9][0-9]*") || !accounts.add(Integer.parseInt(value)))
          throw new IllegalArgumentException("Invalid or duplicate account scope");
      }
      if (result.putIfAbsent(pair[0], new Grant(grant[0], Set.copyOf(accounts))) != null)
        throw new IllegalArgumentException("Duplicate subject mapping");
    }
    if (result.isEmpty()) throw new IllegalArgumentException("Empty entitlement configuration");
    return Map.copyOf(result);
  }

  private JwtAuthenticationToken identity() {
    var authentication = SecurityContextHolder.getContext().getAuthentication();
    if (!(authentication instanceof JwtAuthenticationToken jwt) || !jwt.isAuthenticated())
      throw new AccessDeniedException("Forbidden");
    return jwt;
  }

  private Grant grant() {
    Grant grant = grants.get(identity().getToken().getSubject());
    if (grant == null) throw new AccessDeniedException("Forbidden");
    return grant;
  }

  public Set<Integer> accounts() { return grant().accounts(); }
  public void requireAccount(Integer account) {
    if (account == null || !accounts().contains(account)) throw new AccessDeniedException("Forbidden");
  }
  public void requireTrader() {
    if (!grant().role().equals("trader")) throw new AccessDeniedException("Forbidden");
  }
  public void requireTrade(Integer account) { requireTrader(); requireAccount(account); }
  public boolean isOperator() {
    try { return grant().role().equals("operator"); }
    catch (AccessDeniedException denied) { return false; }
  }
  public String bearerToken() { grant(); return identity().getToken().getTokenValue(); }
  public String subject() { grant(); return identity().getToken().getSubject(); }
  public String issuer() { grant(); return identity().getToken().getIssuer().toString(); }

  // Background execution uses the stored accepting principal, never a fabricated HTTP context.
  public void requireAcceptedTrader(String subject, Integer account) {
    Grant grant = subject == null ? null : grants.get(subject);
    if (grant == null || !grant.role().equals("trader") || account == null || !grant.accounts().contains(account))
      throw new AccessDeniedException("Forbidden");
  }
}
