package __PACKAGE__.security;

import __PACKAGE__.model.OrderRecord;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.UUID;
import javax.net.ssl.HttpsURLConnection;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name="lab.execution.enabled",havingValue="true")
public final class MatcherExecution {
  interface Tokens { String token() throws IOException; }
  interface Sender { void send(UUID id,String token) throws IOException; }
  private final JdbcTemplate jdbc;
  private final AcceptedOrderAuthority authority;
  private final Tokens tokens;
  private final Sender sender;

  @Autowired
  public MatcherExecution(JdbcTemplate jdbc,AcceptedOrderAuthority authority,
      @Value("${lab.execution.endpoint}") String endpoint,
      @Value("${lab.execution.token-endpoint}") String tokenEndpoint,
      @Value("${lab.execution.client-id}") String clientId,
      @Value("${lab.execution.secret-file}") String secretFile) {
    this.jdbc=jdbc;this.authority=authority;
    URI base=URI.create(endpoint);
    if(!"https".equals(base.getScheme()) || base.getHost()==null || base.getUserInfo()!=null
        || base.getQuery()!=null || base.getFragment()!=null || !"/internal/executions/".equals(base.getPath()))
      throw new IllegalArgumentException("Invalid execution endpoint");
    var client=new ServiceTokenClient(URI.create(tokenEndpoint),clientId,Path.of(secretFile));
    this.tokens=client::token;
    this.sender=(id,token)->send(base.resolve(id.toString()),token);
  }

  MatcherExecution(JdbcTemplate jdbc,AcceptedOrderAuthority authority,Tokens tokens,Sender sender) {
    this.jdbc=jdbc;this.authority=authority;this.tokens=tokens;this.sender=sender;
  }

  public boolean hasPending(String orderId) {
    Long count=jdbc.queryForObject("SELECT count(*) FROM lab_execution.reservations r WHERE r.order_id=? AND NOT EXISTS (SELECT 1 FROM lab_execution.receipts x WHERE x.execution_id=r.execution_id)",Long.class,orderId);
    return count!=null && count>0;
  }

  public boolean dispatch(OrderRecord order,int quantity,BigDecimal price) {
    // The service identity is not sufficient: check the stored user's currently loaded grants.
    authority.requireEligible(order);
    var pending=jdbc.query("SELECT r.execution_id FROM lab_execution.reservations r WHERE r.order_id=? AND NOT EXISTS (SELECT 1 FROM lab_execution.receipts x WHERE x.execution_id=r.execution_id) ORDER BY r.created_at,r.execution_id LIMIT 1",
        (rs,index)->rs.getObject(1,UUID.class),order.getOrderId());
    UUID id;
    if(pending.isEmpty()) {
      id=UUID.randomUUID();
      UUID stored=jdbc.queryForObject("SELECT lab_execution.reserve(?,?,?,?)",UUID.class,id,order.getOrderId(),quantity,price);
      if(!id.equals(stored)) throw new IllegalStateException("Reservation mismatch");
    } else id=pending.getFirst();
    try { sender.send(id,tokens.token()); }
    catch(IOException unavailable) { /* Ambiguous response: query durable outcome; retain pending ID. */ }
    Long receipts=jdbc.queryForObject("SELECT count(*) FROM lab_execution.receipts WHERE execution_id=? AND trade_id=?",Long.class,id,id.toString());
    return Long.valueOf(1).equals(receipts);
  }

  public void cancel(String orderId,Integer account) {
    String result=jdbc.queryForObject("SELECT lab_execution.cancel_order(?,?)",String.class,orderId,account);
    if(!orderId.equals(result)) throw new IllegalStateException("Cancellation mismatch");
  }

  private static void send(URI endpoint,String token) throws IOException {
    var connection=(HttpsURLConnection)endpoint.toURL().openConnection();
    try {
      connection.setInstanceFollowRedirects(false);connection.setConnectTimeout(5000);connection.setReadTimeout(5000);
      connection.setRequestMethod("POST");connection.setRequestProperty("Authorization","Bearer "+token);
      connection.setRequestProperty("Accept","application/json");
      if(connection.getResponseCode()!=200) throw new IOException("Execution unavailable");
      // HTTP success is not settlement evidence. Drain only a bounded response then query SQL receipt.
      try(var input=connection.getInputStream()) {
        if(input.readNBytes(65537).length>65536) throw new IOException("Execution unavailable");
      }
    } finally {connection.disconnect();}
  }
}
