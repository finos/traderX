package finos.traderx.accountservice.security;

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
public final class AccountAccess {
  private final Map<String, Set<Integer>> entitlements;

  public AccountAccess(@Value("${lab.identity.entitlements-file}") String filename) throws Exception {
    Path path = Path.of(filename);
    if (!path.isAbsolute()) throw new IllegalArgumentException("Absolute entitlement path required");
    entitlements = parse(Files.readString(path));
  }

  static Map<String, Set<Integer>> parse(String text) {
    Map<String, Set<Integer>> result = new HashMap<>();
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
      if (!grant[1].isEmpty()) {
        for (String value : grant[1].split(",", -1)) {
          if (!value.matches("[1-9][0-9]*")) throw new IllegalArgumentException("Invalid account scope");
          if (!accounts.add(Integer.parseInt(value))) throw new IllegalArgumentException("Duplicate account scope");
        }
      }
      if (result.putIfAbsent(pair[0], Set.copyOf(accounts)) != null)
        throw new IllegalArgumentException("Duplicate subject mapping");
    }
    if (result.isEmpty()) throw new IllegalArgumentException("Empty entitlement configuration");
    return Map.copyOf(result);
  }

  public Set<Integer> accounts() {
    var authentication = SecurityContextHolder.getContext().getAuthentication();
    if (!(authentication instanceof JwtAuthenticationToken jwt) || !jwt.isAuthenticated())
      throw new AccessDeniedException("Forbidden");
    Set<Integer> accounts = entitlements.get(jwt.getToken().getSubject());
    if (accounts == null) throw new AccessDeniedException("Forbidden");
    return accounts;
  }

  public void requireAccount(int id) {
    if (!accounts().contains(id)) throw new AccessDeniedException("Forbidden");
  }
}
