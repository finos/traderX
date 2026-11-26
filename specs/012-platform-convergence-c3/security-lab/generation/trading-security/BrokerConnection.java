package __PACKAGE__.security;

import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.io.IOException;
import java.net.Socket;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermission;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.util.Arrays;
import java.util.Set;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509ExtendedTrustManager;

/** Fixed-origin TLS broker connection. Credentials never enter URLs or diagnostics. */
public final class BrokerConnection {
  private BrokerConnection() {}

  static String secret(Path path) throws IOException {
    if (!path.isAbsolute() || !Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS)
        || Files.getPosixFilePermissions(path).stream().anyMatch(p -> !Set.of(
            PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE).contains(p)))
      throw new IOException("Private broker credential file required");
    try (var input=Files.newInputStream(path)) {
      byte[] bytes=input.readNBytes(4097);
      if(bytes.length==0 || bytes.length>4096) throw new IOException("Invalid broker credential");
      String value=new String(bytes,StandardCharsets.UTF_8).strip();
      if(value.isEmpty() || value.chars().anyMatch(Character::isISOControl))
        throw new IOException("Invalid broker credential");
      return value;
    }
  }

  static URI endpoint(String value) {
    URI uri=URI.create(value);
    if(!"tls".equals(uri.getScheme()) || uri.getHost()==null || uri.getPort()<1
        || uri.getPort()>65535 || uri.getUserInfo()!=null || uri.getQuery()!=null
        || uri.getFragment()!=null || !uri.getPath().isEmpty())
      throw new IllegalArgumentException("Explicit TLS broker origin required");
    return uri;
  }

  public static Connection connect(String address,String username,String filename) throws IOException {
    try {
      URI uri=endpoint(address);
      if(username==null || !username.matches("[A-Za-z0-9_-]{1,64}")) throw new IOException();
      var options=new Options.Builder().server(uri.toString()).noResolveHostnames()
          .ignoreDiscoveredServers().sslContext(verifiedContext()).tlsFirst()
          .userInfo(username,secret(Path.of(filename))).maxReconnects(3)
          .reconnectWait(Duration.ofSeconds(1)).reconnectBufferSize(65536)
          .connectionTimeout(Duration.ofSeconds(5)).socketWriteTimeout(Duration.ofSeconds(2)).build();
      return Nats.connect(options);
    } catch(Exception unavailable) {
      // Safe fixed category only: broker exceptions may contain endpoint credentials.
      String category="other";
      for(Throwable cause=unavailable;cause!=null;cause=cause.getCause()) {
        if(cause instanceof javax.net.ssl.SSLException || cause instanceof CertificateException) { category="tls";break; }
        if(cause instanceof IllegalArgumentException) category="configuration";
        else if(cause instanceof InterruptedException) category="interrupted";
        else if(cause instanceof IOException && category.equals("other")) category="io";
      }
      throw new IOException("Authenticated broker unavailable; broker-failure="+category);
    }
  }

  static SSLContext verifiedContext() throws Exception {
    var factory=TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
    factory.init((KeyStore)null);
    var delegate=Arrays.stream(factory.getTrustManagers()).filter(X509ExtendedTrustManager.class::isInstance)
        .map(X509ExtendedTrustManager.class::cast).findFirst().orElseThrow();
    var context=SSLContext.getInstance("TLS");
    context.init(null,new TrustManager[]{new ServerTrust(delegate)},null);
    return context;
  }

  // jnats 2.20.5 delegates chain validation but does not select a hostname policy.
  // Select the JDK HTTPS endpoint algorithm before delegating server validation;
  // the platform trust manager checks the peer name and certificate chain together.
  static final class ServerTrust extends X509ExtendedTrustManager {
    private final X509ExtendedTrustManager delegate;
    ServerTrust(X509ExtendedTrustManager delegate) { this.delegate=delegate; }
    public void checkServerTrusted(X509Certificate[] chain,String type,Socket socket) throws CertificateException {
      if(!(socket instanceof SSLSocket tls)) throw new CertificateException("TLS socket required");
      var parameters=tls.getSSLParameters();parameters.setEndpointIdentificationAlgorithm("HTTPS");tls.setSSLParameters(parameters);
      delegate.checkServerTrusted(chain,type,socket);
    }
    public void checkServerTrusted(X509Certificate[] chain,String type,SSLEngine engine) throws CertificateException {
      var parameters=engine.getSSLParameters();parameters.setEndpointIdentificationAlgorithm("HTTPS");engine.setSSLParameters(parameters);
      delegate.checkServerTrusted(chain,type,engine);
    }
    public void checkServerTrusted(X509Certificate[] chain,String type) throws CertificateException {
      throw new CertificateException("TLS peer context required");
    }
    public void checkClientTrusted(X509Certificate[] chain,String type) throws CertificateException { delegate.checkClientTrusted(chain,type); }
    public void checkClientTrusted(X509Certificate[] chain,String type,Socket socket) throws CertificateException { delegate.checkClientTrusted(chain,type,socket); }
    public void checkClientTrusted(X509Certificate[] chain,String type,SSLEngine engine) throws CertificateException { delegate.checkClientTrusted(chain,type,engine); }
    public X509Certificate[] getAcceptedIssuers() { return delegate.getAcceptedIssuers(); }
  }
}
