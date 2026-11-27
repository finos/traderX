package finos.traderx.accountservice.security;

import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;

@Configuration
public class AccountSecurity {
  @Bean
  JwtDecoder jwtDecoder(@Value("${lab.identity.issuer}") String issuer,
                        @Value("${lab.identity.audience}") String audience,
                        @Value("${lab.identity.public-key-file}") String filename,
                        @Value("${lab.identity.key-not-after}") String keyNotAfter) throws Exception {
    URI uri = URI.create(issuer);
    if (!"https".equals(uri.getScheme()) || uri.getHost() == null || uri.getUserInfo() != null || uri.getQuery() != null || uri.getFragment() != null || audience.isBlank())
      throw new IllegalArgumentException("Invalid trusted issuer/audience configuration");
    Path path = Path.of(filename);
    if (!path.isAbsolute()) throw new IllegalArgumentException("Absolute public-key path required");
    String pem = Files.readString(path).replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "").replaceAll("\\s", "");
    RSAPublicKey key = (RSAPublicKey) KeyFactory.getInstance("RSA").generatePublic(new X509EncodedKeySpec(Base64.getDecoder().decode(pem)));
    if (key.getModulus().bitLength() < 2048) throw new IllegalArgumentException("RSA key too small");
    Instant trustExpiry = Instant.parse(keyNotAfter);
    if (!trustExpiry.isAfter(Instant.now())) throw new IllegalArgumentException("Expired trust snapshot");
    NimbusJwtDecoder decoder = NimbusJwtDecoder.withPublicKey(key).signatureAlgorithm(SignatureAlgorithm.RS256).build();
    decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(new JwtIssuerValidator(issuer),
        new JwtTimestampValidator(Duration.ZERO), requiredClaims(audience, trustExpiry)));
    return decoder;
  }

  static OAuth2TokenValidator<Jwt> requiredClaims(String audience, Instant trustExpiry) {
    return jwt -> {
      Instant now = Instant.now();
      boolean valid = now.isBefore(trustExpiry) && jwt.getSubject() != null && !jwt.getSubject().isBlank()
          && jwt.getAudience() != null && jwt.getAudience().contains(audience)
          && jwt.getIssuedAt() != null && !jwt.getIssuedAt().isAfter(now)
          && jwt.getExpiresAt() != null && jwt.getExpiresAt().isAfter(now)
          && jwt.getExpiresAt().isAfter(jwt.getIssuedAt());
      return valid ? OAuth2TokenValidatorResult.success() : OAuth2TokenValidatorResult.failure(
          new OAuth2Error("invalid_token", "Required access-token claims or trust window invalid", null));
    };
  }

  @Bean
  SecurityFilterChain accountChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .requestCache(cache -> cache.disable())
        .formLogin(form -> form.disable()).httpBasic(basic -> basic.disable()).logout(logout -> logout.disable())
        .cors(cors -> cors.configurationSource(request -> new CorsConfiguration()))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(HttpMethod.GET, "/actuator/health").permitAll()
            .requestMatchers(HttpMethod.GET, "/account/", "/account/*", "/accountuser/", "/accountuser/*").authenticated()
            .anyRequest().denyAll())
        .oauth2ResourceServer(oauth -> oauth.jwt(Customizer.withDefaults()));
    return http.build();
  }
}
