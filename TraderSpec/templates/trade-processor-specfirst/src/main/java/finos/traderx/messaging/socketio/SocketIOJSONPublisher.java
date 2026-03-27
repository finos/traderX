package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.socket.client.IO;
import io.socket.client.Socket;
import io.socket.emitter.Emitter;
import java.net.URI;
import org.json.JSONObject;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public abstract class SocketIOJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  protected IO.Options getIOOptions() {
    return new IO.Options();
  }

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  boolean connected = false;
  Socket socket;
  String socketAddress = "http://localhost:3000";
  String topic = "/default";

  public void setSocketAddress(String addr) {
    socketAddress = addr;
  }

  public void setTopic(String topic) {
    this.topic = topic;
  }

  @Override
  public boolean isConnected() {
    return connected;
  }

  @Override
  public void publish(T message) throws PubSubException {
    publish(topic, message);
  }

  @Override
  public void publish(String topic, T message) throws PubSubException {
    if (!isConnected()) {
      throw new PubSubException("Cannot send %s on topic %s - not connected".formatted(message, topic));
    }
    try {
      SocketIOEnvelope<T> envelope = new SocketIOEnvelope<>(topic, message);
      String msgString = OBJECT_MAPPER.writerFor(SocketIOEnvelope.class).writeValueAsString(envelope);
      JSONObject obj = new JSONObject(msgString);
      log.debug("PUBLISH->{}", obj);
      socket.emit("publish", obj);
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    if (socket != null && isConnected()) {
      socket.disconnect();
    }
    socket = null;
  }

  @Override
  public void connect() throws PubSubException {
    if (socket != null) {
      socket.disconnect();
    }
    try {
      socket = internalConnect(URI.create(socketAddress));
    } catch (Exception x) {
      throw new PubSubException("Cannot socket connection at " + socketAddress, x);
    }
  }

  protected Socket internalConnect(URI uri) throws Exception {
    return IO.socket(uri, getIOOptions());
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
    socket.on(Socket.EVENT_CONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = true;
        log.info("Socket Connected {}", args);
      }
    });

    socket.on(Socket.EVENT_DISCONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = false;
        log.info("Socket Disconnected {}", args);
      }
    });

    socket.on(Socket.EVENT_CONNECT_ERROR, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = false;
        log.info("Connection Error {}", args);
      }
    });
    socket.connect();
  }
}
