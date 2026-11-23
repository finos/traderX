import finos.traderx.messaging.nats.NatsJSONPublisher;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PublisherProbe {
  public static void main(String[] args) throws Exception {
    var publisher=new NatsJSONPublisher<String>();
    if(args[0].equals("status-regression")) {
      var field=publisher.getClass().getDeclaredField("connection");field.setAccessible(true);
      var connection=java.lang.reflect.Proxy.newProxyInstance(io.nats.client.Connection.class.getClassLoader(),new Class[]{io.nats.client.Connection.class},(proxy,method,values)->method.getName().equals("getStatus")?io.nats.client.Connection.Status.DISCONNECTED:null);
      field.set(publisher,connection);
      if(publisher.isConnected())throw new AssertionError("DISCONNECTED was reported as connected");
      System.out.println("LAB_STATUS_OK");return;
    }
    publisher.setServerAddress(System.getenv("NATS_ADDRESS"));publisher.setTopic(args[0]);
    publisher.afterPropertiesSet();System.out.println("LAB_READY");
    try(var input=new BufferedReader(new InputStreamReader(System.in))) {
      String line;
      while((line=input.readLine())!=null) {
        try {publisher.publish(line);System.out.println("LAB_SENT "+line);}
        catch(Exception error) {System.out.println("LAB_RETRY");}
      }
    } finally {publisher.disconnect();}
  }
}
