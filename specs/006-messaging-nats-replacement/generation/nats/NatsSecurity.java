package finos.traderx.messaging.nats;

import io.nats.client.Options;
import java.net.URI;
import java.net.Socket;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.util.Map;
import javax.net.ssl.*;

/** Optional projected credentials with fail-closed TLS and endpoint verification. */
public final class NatsSecurity {
  private NatsSecurity() {}
  public static Options options(String address) {
    return options(address, System.getenv());
  }
  public static Options options(String address, Map<String, String> env) {
    try {
      URI uri = URI.create(address);
      if (uri.getRawUserInfo() != null) throw new IllegalArgumentException();
      Options.Builder builder = new Options.Builder().server(address).maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5));
      boolean enabled = java.util.List.of("NATS_SECURITY_REQUIRED", "NATS_USER_FILE", "NATS_PASSWORD_FILE", "NATS_CA_FILE")
          .stream().anyMatch(env::containsKey);
      if (!enabled) return builder.build();
      if (!"true".equals(env.get("NATS_SECURITY_REQUIRED")) || !"tls".equals(uri.getScheme())
          || uri.getHost() == null || uri.getRawQuery() != null || uri.getRawFragment() != null
          || (uri.getPath() != null && !uri.getPath().isEmpty())) throw new IllegalArgumentException();
      String user = secret(env, "NATS_USER_FILE"), password = secret(env, "NATS_PASSWORD_FILE");
      Path ca = absolute(env, "NATS_CA_FILE");
      KeyStore trust = KeyStore.getInstance(KeyStore.getDefaultType());
      trust.load(null, null);
      try (var input = Files.newInputStream(ca)) {
        int i = 0;
        for (var cert : CertificateFactory.getInstance("X.509").generateCertificates(input)) {
          trust.setCertificateEntry("ca-" + i++, cert);
        }
        if (i == 0) throw new IllegalArgumentException();
      }
      TrustManagerFactory factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
      factory.init(trust);
      X509ExtendedTrustManager delegate = null;
      for (TrustManager manager : factory.getTrustManagers()) {
        if (manager instanceof X509ExtendedTrustManager extended) delegate = extended;
      }
      if (delegate == null) throw new IllegalStateException();
      SSLContext context = SSLContext.getInstance("TLS");
      context.init(null, new TrustManager[]{new EndpointTrust(delegate)}, null);
      return builder.userInfo(user, password).sslContext(context).tlsFirst().noResolveHostnames().build();
    } catch (Exception ignored) {
      // Do not propagate credential-bearing URIs, file contents or provider exceptions.
      throw new IllegalArgumentException("Invalid NATS security configuration");
    }
  }
  private static Path absolute(Map<String,String> env, String key) {
    Path path = Path.of(env.get(key));
    if (!path.isAbsolute()) throw new IllegalArgumentException();
    return path;
  }
  private static String secret(Map<String,String> env, String key) throws Exception {
    String value = Files.readString(absolute(env,key)).replaceFirst("\\r?\\n$", "");
    if (value.isEmpty() || value.contains("\n") || value.contains("\r") || value.contains("\0")) throw new IllegalArgumentException();
    return value;
  }
  private static final class EndpointTrust extends X509ExtendedTrustManager {
    private final X509ExtendedTrustManager delegate;
    EndpointTrust(X509ExtendedTrustManager delegate) { this.delegate = delegate; }
    public X509Certificate[] getAcceptedIssuers() { return delegate.getAcceptedIssuers(); }
    public void checkServerTrusted(X509Certificate[] chain, String auth, Socket socket) throws CertificateException {
      if (!(socket instanceof SSLSocket ssl)) throw new CertificateException("TLS endpoint required");
      SSLParameters params = ssl.getSSLParameters();
      params.setEndpointIdentificationAlgorithm("HTTPS");
      ssl.setSSLParameters(params);
      delegate.checkServerTrusted(chain, auth, socket);
    }
    public void checkServerTrusted(X509Certificate[] chain, String auth, SSLEngine engine) throws CertificateException {
      SSLParameters params = engine.getSSLParameters();
      params.setEndpointIdentificationAlgorithm("HTTPS");
      engine.setSSLParameters(params);
      delegate.checkServerTrusted(chain, auth, engine);
    }
    public void checkServerTrusted(X509Certificate[] chain, String auth) throws CertificateException {
      throw new CertificateException("TLS endpoint required");
    }
    public void checkClientTrusted(X509Certificate[] chain, String auth) throws CertificateException { delegate.checkClientTrusted(chain,auth); }
    public void checkClientTrusted(X509Certificate[] chain, String auth, Socket socket) throws CertificateException { delegate.checkClientTrusted(chain,auth,socket); }
    public void checkClientTrusted(X509Certificate[] chain, String auth, SSLEngine engine) throws CertificateException { delegate.checkClientTrusted(chain,auth,engine); }
  }
}
