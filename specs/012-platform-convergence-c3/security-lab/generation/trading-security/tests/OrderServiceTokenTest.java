package __PACKAGE__.security;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.*;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class OrderServiceTokenTest {
  @TempDir Path directory;
  static final URI ENDPOINT=URI.create("https://identity.example.test/realms/lab/protocol/openid-connect/token");
  static final String RESPONSE="{\"access_token\":\"header.payload.signature\",\"token_type\":\"Bearer\",\"expires_in\":60}";
  static class Time extends Clock {
    Instant now=Instant.parse("2026-11-25T00:00:00Z");
    public Instant instant(){return now;} public ZoneId getZone(){return ZoneOffset.UTC;}
    public Clock withZone(ZoneId zone){return this;}
  }
  Path secret(String value) throws Exception {var p=directory.resolve("secret");Files.writeString(p,value);return p;}
  @Test void rejectsUntrustedTransportConfiguration() throws Exception {
    for(String endpoint:List.of("http://identity.example.test/token","https://user@identity.example.test/token","https://identity.example.test/token?next=evil","https://identity.example.test/token#x"))
      assertThrows(IllegalArgumentException.class,()->new ServiceTokenClient(URI.create(endpoint),"matcher",directory.resolve("secret")));
    assertThrows(IllegalArgumentException.class,()->new ServiceTokenClient(ENDPOINT,"matcher",Path.of("relative")));
  }
  @Test void encodesCredentialsAndCachesOnlyWithinRefreshWindow() throws Exception {
    var clock=new Time();var count=new AtomicInteger();var form=new AtomicReference<String>();
    var client=new ServiceTokenClient(ENDPOINT,"matcher id",secret("secret&=+"),clock,(uri,body)->{count.incrementAndGet();form.set(new String(body,java.nio.charset.StandardCharsets.UTF_8));return RESPONSE;});
    assertEquals("header.payload.signature",client.token());assertEquals(client.token(),client.token());assertEquals(1,count.get());
    assertEquals("grant_type=client_credentials&client_id=matcher+id&client_secret=secret%26%3D%2B",form.get());
    clock.now=clock.now.plusSeconds(30);Files.writeString(directory.resolve("secret"),"rotated");client.token();
    assertEquals(2,count.get());assertTrue(form.get().endsWith("client_secret=rotated"));
  }
  @Test void refreshFailureNeverReturnsCachedTokenOrSensitiveErrors() throws Exception {
    var clock=new Time();var count=new AtomicInteger();
    var client=new ServiceTokenClient(ENDPOINT,"matcher",secret("sensitive"),clock,(uri,body)->{if(count.incrementAndGet()>1)throw new IOException("sensitive response");return RESPONSE;});
    client.token();clock.now=clock.now.plusSeconds(30);
    var failure=assertThrows(IOException.class,client::token);
    assertEquals("Service token unavailable",failure.getMessage());assertNull(failure.getCause());
    assertThrows(IOException.class,client::token);assertEquals(3,count.get());
  }
  @Test void malformedAndUnboundedResponsesFailClosed() throws Exception {
    for(String response:List.of("{}","broken",RESPONSE.replace("Bearer","Basic"),RESPONSE.replace("60","0"),RESPONSE.replace("60","301"),RESPONSE.replace("60","\"60\""),RESPONSE.replace("header.payload.signature","not-a-jwt"),"x".repeat(65537))) {
      var client=new ServiceTokenClient(ENDPOINT,"matcher",secret("secret"),new Time(),(uri,body)->response);
      assertThrows(IOException.class,client::token);
    }
  }
  @Test void missingOversizedAndMalformedSecretsNeverReachTransport() throws Exception {
    for(String value:List.of("","x".repeat(4097),"secret\nsecond")) {
      var client=new ServiceTokenClient(ENDPOINT,"matcher",secret(value),new Time(),(uri,body)->{fail("Transport must not run");return RESPONSE;});
      assertThrows(IOException.class,client::token);
    }
    Files.delete(directory.resolve("secret"));
    assertThrows(IOException.class,()->new ServiceTokenClient(ENDPOINT,"matcher",directory.resolve("secret")).token());
  }
  @Test void tokenThatExpiredDuringRequestIsRejected() throws Exception {
    var clock=new Time();
    var client=new ServiceTokenClient(ENDPOINT,"matcher",secret("secret"),clock,(uri,body)->{clock.now=clock.now.plusSeconds(61);return RESPONSE;});
    assertThrows(IOException.class,client::token);
  }
  @Test void redirectIsNeverFollowedAndConnectionIsClosed() throws Exception {
    var connection=mock(javax.net.ssl.HttpsURLConnection.class);
    when(connection.getOutputStream()).thenReturn(new java.io.ByteArrayOutputStream());
    when(connection.getResponseCode()).thenReturn(302);
    assertThrows(IOException.class,()->ServiceTokenClient.exchange(connection,new byte[]{1}));
    verify(connection).setInstanceFollowRedirects(false);
    verify(connection).setConnectTimeout(5000);verify(connection).setReadTimeout(5000);
    verify(connection,never()).getInputStream();verify(connection).disconnect();
  }
  @Test void transportRejectsOversizedResponseAndDisconnects() throws Exception {
    var connection=mock(javax.net.ssl.HttpsURLConnection.class);
    when(connection.getOutputStream()).thenReturn(new java.io.ByteArrayOutputStream());
    when(connection.getResponseCode()).thenReturn(200);
    when(connection.getInputStream()).thenReturn(new java.io.ByteArrayInputStream(new byte[65537]));
    assertThrows(IOException.class,()->ServiceTokenClient.exchange(connection,new byte[]{1}));
    verify(connection).disconnect();
  }
}
