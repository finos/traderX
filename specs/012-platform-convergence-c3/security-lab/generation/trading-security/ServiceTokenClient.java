package __PACKAGE__.security;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import javax.net.ssl.HttpsURLConnection;
import tools.jackson.databind.ObjectMapper;

/** Client-credentials transport only; does not confer business or account authority. */
public final class ServiceTokenClient {
  interface Transport { String exchange(URI endpoint, byte[] form) throws IOException; }
  private final URI endpoint;
  private final String clientId;
  private final Path secretFile;
  private final Clock clock;
  private final Transport transport;
  private String cached;
  private Instant refreshAt = Instant.MIN;

  public ServiceTokenClient(URI endpoint, String clientId, Path secretFile) {
    this(endpoint,clientId,secretFile,Clock.systemUTC(),ServiceTokenClient::exchange);
  }

  ServiceTokenClient(URI endpoint,String clientId,Path secretFile,Clock clock,Transport transport) {
    if (!"https".equals(endpoint.getScheme()) || endpoint.getHost()==null || endpoint.getUserInfo()!=null
        || endpoint.getQuery()!=null || endpoint.getFragment()!=null || clientId==null || clientId.isBlank()
        || clientId.length()>255 || !secretFile.isAbsolute()) throw new IllegalArgumentException("Invalid service-token configuration");
    this.endpoint=endpoint;this.clientId=clientId;this.secretFile=secretFile;this.clock=clock;this.transport=transport;
  }

  public synchronized String token() throws IOException {
    Instant now=clock.instant();
    if (cached!=null && now.isBefore(refreshAt)) return cached;
    // A failed refresh must never fall back to an old token.
    cached=null;refreshAt=Instant.MIN;
    try {
      String secret;
      try(var stream=Files.newInputStream(secretFile)) {
        byte[] bytes=stream.readNBytes(4097);
        if(bytes.length==0 || bytes.length>4096) throw new IOException();
        secret=new String(bytes,StandardCharsets.UTF_8).strip();
      }
      if(secret.isEmpty() || secret.chars().anyMatch(Character::isISOControl)) throw new IOException();
      String form="grant_type=client_credentials&client_id="+encode(clientId)+"&client_secret="+encode(secret);
      String response=transport.exchange(endpoint,form.getBytes(StandardCharsets.UTF_8));
      if(response==null || response.length()>65536) throw new IOException();
      var json=new ObjectMapper().readTree(response);
      if(json==null || !json.isObject()) throw new IOException();
      var type=json.get("token_type");var access=json.get("access_token");var expires=json.get("expires_in");
      if(type==null || !type.isString() || !"Bearer".equalsIgnoreCase(type.asText())
          || access==null || !access.isString() || !access.asText().matches("[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+")
          || expires==null || !expires.isIntegralNumber() || !expires.asText().matches("[1-9][0-9]{0,2}")) throw new IOException();
      int seconds=Integer.parseInt(expires.asText());
      if(seconds>300 || !clock.instant().isBefore(now.plusSeconds(seconds))) throw new IOException();
      cached=access.asText();refreshAt=now.plusSeconds(Math.max(0,seconds-30));
      return cached;
    } catch(Exception failure) {
      // Do not retain credential-bearing transport errors or responses as causes.
      throw new IOException("Service token unavailable");
    }
  }

  private static String encode(String value) { return URLEncoder.encode(value,StandardCharsets.UTF_8); }

  private static String exchange(URI endpoint,byte[] form) throws IOException {
    return exchange((HttpsURLConnection)endpoint.toURL().openConnection(),form);
  }

  static String exchange(HttpsURLConnection connection,byte[] form) throws IOException {
    try {
      connection.setInstanceFollowRedirects(false);
      connection.setConnectTimeout(5000);connection.setReadTimeout(5000);
      connection.setRequestMethod("POST");connection.setDoOutput(true);
      connection.setRequestProperty("Content-Type","application/x-www-form-urlencoded");
      connection.setRequestProperty("Accept","application/json");
      connection.setFixedLengthStreamingMode(form.length);
      try(var stream=connection.getOutputStream()) {stream.write(form);}
      if(connection.getResponseCode()!=200) throw new IOException("Service token unavailable");
      try(var stream=connection.getInputStream()) {
        byte[] bytes=stream.readNBytes(65537);
        if(bytes.length>65536) throw new IOException("Service token unavailable");
        return new String(bytes,StandardCharsets.UTF_8);
      }
    } finally {connection.disconnect();}
  }
}
