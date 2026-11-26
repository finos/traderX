package __PACKAGE__.security;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.cert.CertificateException;
import java.time.Duration;
import io.nats.client.Options;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.X509ExtendedTrustManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class OrderBrokerConnectionTest {
  @TempDir Path temp;

  @Test void refusesPlaintextUserinfoAndCallerSelectedPaths() {
    for(String url:new String[]{"nats://localhost:4222","tls://u:p@localhost:4222","tls://localhost:4222/path","tls://localhost:4222?q=x","tls://localhost"})
      assertThrows(IllegalArgumentException.class,()->BrokerConnection.endpoint(url));
    assertEquals("localhost",BrokerConnection.endpoint("tls://localhost:4222").getHost());
  }
  @Test void requiresPrivateBoundedCredentialFile() throws Exception {
    Path value=temp.resolve("secret");Files.writeString(value,"synthetic-private-value");
    Files.setPosixFilePermissions(value,PosixFilePermissions.fromString("rw-------"));
    assertEquals("synthetic-private-value",BrokerConnection.secret(value));
    Path link=temp.resolve("link");Files.createSymbolicLink(link,value);
    assertThrows(java.io.IOException.class,()->BrokerConnection.secret(link));
    Files.setPosixFilePermissions(value,PosixFilePermissions.fromString("rw-r--r--"));
    assertThrows(java.io.IOException.class,()->BrokerConnection.secret(value));
    Files.setPosixFilePermissions(value,PosixFilePermissions.fromString("rw-------"));Files.writeString(value,"x".repeat(4097));
    assertThrows(java.io.IOException.class,()->BrokerConnection.secret(value));
  }
  @Test void serverValidationRequiresPeerContextAndPreservesPlatformRejection() throws Exception {
    var delegate=mock(X509ExtendedTrustManager.class);var trust=new BrokerConnection.ServerTrust(delegate);
    assertThrows(CertificateException.class,()->trust.checkServerTrusted(null,"RSA"));
    SSLEngine engine=SSLContext.getDefault().createSSLEngine("unexpected.invalid",4222);
    doAnswer(call->{
      assertEquals("HTTPS",engine.getSSLParameters().getEndpointIdentificationAlgorithm());
      throw new CertificateException("Wrong peer");
    }).when(delegate).checkServerTrusted(null,"RSA",engine);
    assertThrows(CertificateException.class,()->trust.checkServerTrusted(null,"RSA",engine));
    verify(delegate).checkServerTrusted(null,"RSA",engine);
  }

  @Test void buildsBoundedAuthenticatedTlsOptionsWithoutOpeningConnection() throws Exception {
    Path value=temp.resolve("options-secret");Files.writeString(value,"synthetic-private-value");
    Files.setPosixFilePermissions(value,PosixFilePermissions.fromString("rw-------"));
    SSLContext context=BrokerConnection.verifiedContext();
    Options options=assertDoesNotThrow(()->BrokerConnection.options("tls://localhost:4222","matcher",value.toString(),context));
    assertSame(context,options.getSslContext());
    assertEquals(Duration.ofSeconds(5),options.getConnectionTimeout());
    assertEquals(Duration.ofSeconds(10),options.getSocketWriteTimeout());
    assertTrue(options.getSocketWriteTimeout().toMillis()>=options.getConnectionTimeout().toMillis()
        + Options.MINIMUM_SOCKET_WRITE_TIMEOUT_GT_CONNECTION_TIMEOUT);
    assertEquals(3,options.getMaxReconnect());
    assertEquals(65536,options.getReconnectBufferSize());
  }
}
