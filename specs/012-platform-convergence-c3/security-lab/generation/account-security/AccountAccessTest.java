package finos.traderx.accountservice.security;

import static org.junit.jupiter.api.Assertions.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class AccountAccessTest {
  @TempDir Path directory;

  @Test void malformedAndDuplicateMappingsFailClosed() {
    for (String text : new String[]{"", "reader=admin:1", "reader=trader:0", "reader=trader:1,1", "reader=trader:1\nreader=operator:2", "reader=trader:1,", "reader=trader:bad"})
      assertThrows(IllegalArgumentException.class, () -> AccountAccess.parse(text));
  }

  @Test void trustedMappingOverridesTokenClaimsAndOperatorHasNoImplicitAccess() throws Exception {
    Path file=directory.resolve("entitlements");
    Files.writeString(file,"reader=read-only:22214\ntrader=trader:62654\noperator=operator:\n");
    AccountAccess access=new AccountAccess(file.toString());
    try {
      for (String subject : new String[]{"reader","trader","operator","unknown"}) {
        Jwt jwt=Jwt.withTokenValue("fixture").header("alg","RS256").subject(subject)
            .claim("accounts",java.util.List.of(22214,62654)).claim("role","operator").build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt,java.util.List.of()));
        if (subject.equals("unknown")) assertThrows(AccessDeniedException.class,access::accounts);
        else if (subject.equals("operator")) assertTrue(access.accounts().isEmpty());
        else {
          int own=subject.equals("reader")?22214:62654;
          access.requireAccount(own);
          assertThrows(AccessDeniedException.class,()->access.requireAccount(own==22214?62654:22214));
        }
      }
    } finally { SecurityContextHolder.clearContext(); }
    assertThrows(AccessDeniedException.class,access::accounts);
  }

  @Test void requiredClaimsAndExpiredTrustRejectTokens() {
    Instant now=Instant.now();
    Jwt valid=Jwt.withTokenValue("fixture").header("alg","RS256").subject("reader")
        .audience(java.util.List.of("account-api")).issuedAt(now.minusSeconds(1)).expiresAt(now.plusSeconds(60)).build();
    assertFalse(AccountSecurity.requiredClaims("account-api",now.plusSeconds(300)).validate(valid).hasErrors());
    assertTrue(AccountSecurity.requiredClaims("other-api",now.plusSeconds(300)).validate(valid).hasErrors());
    assertTrue(AccountSecurity.requiredClaims("account-api",now.minusSeconds(1)).validate(valid).hasErrors());
    Jwt missing=Jwt.withTokenValue("fixture").header("alg","RS256").subject("reader").build();
    assertTrue(AccountSecurity.requiredClaims("account-api",now.plusSeconds(300)).validate(missing).hasErrors());
  }
}
