package __PACKAGE__.security;

import java.nio.file.Files;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPublicKey;
import java.security.interfaces.RSAPrivateKey;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.MapPropertySource;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

@ExtendWith(SpringExtension.class)
@WebAppConfiguration
@ContextConfiguration(initializers=SecurityTestSupport.Trust.class)
public abstract class SecurityTestSupport {
  static final String ISSUER="https://identity.example.test/realms/lab";
  static final KeyPair KEYS=keys();
  @Autowired WebApplicationContext context;
  MockMvc mvc;
  static KeyPair keys() {
    try { var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);return generator.generateKeyPair(); }
    catch(Exception failure) { throw new RuntimeException(failure); }
  }
  public static class Trust implements ApplicationContextInitializer<ConfigurableApplicationContext> {
    public void initialize(ConfigurableApplicationContext context) {
      try {
        var directory=Files.createTempDirectory("traderx-http-security-");
        var key=directory.resolve("public.pem");
        Files.writeString(key,"-----BEGIN PUBLIC KEY-----\n"+Base64.getEncoder().encodeToString(KEYS.getPublic().getEncoded())+"\n-----END PUBLIC KEY-----");
        var grants=directory.resolve("entitlements.txt");
        Files.writeString(grants,"reader=read-only:22214\ntrader=trader:22214\nother=trader:44044\noperator=operator:\noperator-account=operator:22214\n");
        context.getEnvironment().getPropertySources().addFirst(new MapPropertySource("test-trust",Map.of(
          "lab.identity.issuer",ISSUER,"lab.identity.audience","traderx-api",
          "lab.identity.public-key-file",key.toString(),"lab.identity.entitlements-file",grants.toString(),
          "lab.identity.key-not-after",Instant.now().plusSeconds(600).toString())));
        key.toFile().deleteOnExit();grants.toFile().deleteOnExit();directory.toFile().deleteOnExit();
      } catch(Exception failure) { throw new RuntimeException(failure); }
    }
  }
  @BeforeEach void configureMvc() { mvc=MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build(); }
  String token(String subject) { return token(subject,ISSUER,"traderx-api",300,KEYS); }
  String token(String subject,String issuer,String audience,long expires,KeyPair keys) {
    var jwk=new RSAKey.Builder((RSAPublicKey)keys.getPublic()).privateKey((RSAPrivateKey)keys.getPrivate()).keyID("test").build();
    var encoder=new NimbusJwtEncoder(new ImmutableJWKSet<>(new JWKSet(jwk)));
    var now=Instant.now();
    var claims=JwtClaimsSet.builder().issuer(issuer).subject(subject).audience(java.util.List.of(audience))
      .issuedAt(now.minusSeconds(60)).expiresAt(now.plusSeconds(expires))
      .claim("roles",java.util.List.of("operator","trader")).claim("accountId",44044).build();
    return encoder.encode(JwtEncoderParameters.from(JwsHeader.with(SignatureAlgorithm.RS256).build(),claims)).getTokenValue();
  }
}
