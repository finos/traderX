package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.socket.client.IO;
import io.socket.client.Socket;
import io.socket.emitter.Emitter;
import org.json.JSONObject;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.PubSubException;
import java.net.URI;

/**
 * Simple socketIO Subscribe, which uses 3 commands  - 'subscribe', 'unsubscribe', and 'publish'  followed by payload
 * The server may add additional fields prefixed by underscores, with _from and _at (timestamp) and the 'topic' field gets added
 * to every message.
 * 
 * This is a rudimentary implementation which needs to be fixed to more of an envelope/payload format.
 * 
 */
public abstract class SocketIOJSONSubscriber<T> implements Subscriber<T>, InitializingBean {
    private static ObjectMapper objectMapper = new ObjectMapper().setSerializationInclusion(JsonInclude.Include.NON_NULL);

    public SocketIOJSONSubscriber(Class<T> typeClass){
        this.type=typeClass;
    }

    protected IO.Options getIOOptions(){
        return new IO.Options();
    }

    final Class<T> type;

    org.slf4j.Logger log= LoggerFactory.getLogger(this.getClass().getName());

    boolean connected=false;

    @Override
    public boolean isConnected(){
        return connected;
    }
    @Autowired
    Socket socket;

    String socketAddress="http://localhost:3000";

    public void setSocketAddress(String addr){
        socketAddress=addr;
    }

    public abstract void onMessage(T message);

    @Override
    public void subscribe(String topic) throws PubSubException  {
        log.info("Subscribing to "+topic);
        socket.emit("subscribe", topic);
    }

    @Override
    public void unsubscribe(String topic) throws PubSubException  {
        socket.emit("unsubscribe", "topic");
    }

    @Override
    public void disconnect() throws PubSubException {
        if(socket!=null && isConnected()) socket.disconnect();
        socket=null;
    }

    @Override
    public void connect() throws PubSubException {
        if(socket!=null) socket.disconnect();
        try{
            socket=internalConnect(URI.create(socketAddress));
        } catch (Exception x){ 
            throw new PubSubException("Cannot socket connection at "+socketAddress, x);
        }
    }

    protected Socket internalConnect(URI uri) throws Exception{
        Socket s= IO.socket(uri,getIOOptions());
        s.on(Socket.EVENT_CONNECT, new Emitter.Listener() {
            @Override
            public void call(Object... args) {
                SocketIOJSONSubscriber.this.connected=true;
                log.info("Socket Connected");
            }
        });

        s.on(Socket.EVENT_DISCONNECT, new Emitter.Listener() {
            @Override
            public void call(Object... args) {
                SocketIOJSONSubscriber.this.connected=false;
                log.info("Socket Disconnected");
            }
        });

        s.on(Socket.EVENT_CONNECT_ERROR, new Emitter.Listener() {
            @Override
            public void call(Object... args) {
                SocketIOJSONSubscriber.this.connected=false;
                log.info("Connection Error");
            }
        });

        s.on("publish", new Emitter.Listener() {
            @Override
            public void call(Object... args) {
                try{
                    JSONObject json = (JSONObject) args[0];
                    if("System".equals(json.getString("_from"))) {
                        log.info("INCOMING>>>>> " +args[0].toString());
                    } else {
                        T obj=objectMapper.readValue( scrubJson(json).toString(),  SocketIOJSONSubscriber.this.type );
                        SocketIOJSONSubscriber.this.onMessage(obj);
                    }
                } catch (Exception x){
                    log.error("Threw exception while handling incoming message",x);
                }
                log.info("Connection Error");
            }
        });
        s.connect();
        return s;
    }
    
    // This is a form of 'envelope unwrapping' until a better payload format is introduced
    JSONObject scrubJson(JSONObject obj){
        obj.remove("topic");
        for(String name:JSONObject.getNames(obj)){
            if(name.startsWith("_"))
            obj.remove(name);
        }

        return obj;
    }
    @Override
    public void afterPropertiesSet() throws Exception {
        connect();
       
        socket.connect();
    }
}