import finos.traderx.messaging.nats.NatsJSONSubscriber;
import finos.traderx.messaging.Envelope;
public class SubscriberProbe {
  public static void main(String[] args) throws Exception {
    var subscriber=new NatsJSONSubscriber<String>(String.class) {
      public void onMessage(Envelope<?> envelope,String message) {System.out.println("LAB_RECEIVED "+message);}
    };
    if(args.length>0 && args[0].equals("status-regression")) {
      var field=NatsJSONSubscriber.class.getDeclaredField("connection");field.setAccessible(true);
      var connection=java.lang.reflect.Proxy.newProxyInstance(io.nats.client.Connection.class.getClassLoader(),new Class[]{io.nats.client.Connection.class},(proxy,method,values)->method.getName().equals("getStatus")?io.nats.client.Connection.Status.DISCONNECTED:null);
      field.set(subscriber,connection);
      if(subscriber.isConnected())throw new AssertionError("DISCONNECTED subscriber reported connected");
      System.out.println("LAB_STATUS_OK");return;
    }
    subscriber.setServerAddress(System.getenv("NATS_ADDRESS"));subscriber.setDefaultTopic("/trades");
    subscriber.afterPropertiesSet();System.out.println("LAB_READY");
    try {while(System.in.read()!=-1) {}} finally {subscriber.disconnect();}
  }
}
