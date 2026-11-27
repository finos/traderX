import finos.traderx.messaging.nats.NatsSecurity;
import io.nats.client.Nats;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

public class JavaNatsProbe {
  public static void main(String[] args) throws Exception {
    try {
      if (args[0].equals("legacy")) {
        var options=NatsSecurity.options("nats://localhost:4222",Map.of());
        if(options.getSslContext()!=null) throw new AssertionError();
        try {NatsSecurity.options("nats://localhost:4222",Map.of("NATS_SECURITY_REQUIRED","true"));throw new AssertionError();}
        catch(IllegalArgumentException expected){}
        System.out.println("PASS legacy and fail-closed configuration");return;
      }
      var env=new HashMap<>(System.getenv());
      try(var primary=Nats.connect(NatsSecurity.options(env.get("NATS_ADDRESS"),env))) {
        if(args[0].equals("connect")) {System.out.println("PASS connected");return;}
        var peerEnv=new HashMap<>(env);
        peerEnv.put("NATS_USER_FILE",env.get("PROBE_PEER_USER"));
        peerEnv.put("NATS_PASSWORD_FILE",env.get("PROBE_PEER_PASSWORD"));
        try(var peer=Nats.connect(NatsSecurity.options(env.get("NATS_ADDRESS"),peerEnv))) {
          var subscriber=args[0].equals("publish")?peer:primary;
          var publisher=args[0].equals("publish")?primary:peer;
          var subscription=subscriber.subscribe(args[1]);subscriber.flush(Duration.ofSeconds(3));
          byte[] marker=java.util.UUID.randomUUID().toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
          publisher.publish(args[1],marker);publisher.flush(Duration.ofSeconds(3));
          var message=subscription.nextMessage(Duration.ofSeconds(3));
          if(message==null || !java.util.Arrays.equals(marker,message.getData()))throw new AssertionError("Delivery missing");
          System.out.println("PASS "+args[0]+" "+args[1]);
        }
      }
    } catch(Exception error) { System.err.println("REJECTED "+error.getClass().getSimpleName());System.exit(2); }
  }
}
