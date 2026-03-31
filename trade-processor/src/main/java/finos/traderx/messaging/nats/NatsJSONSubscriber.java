package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Subscriber;
import io.nats.client.Connection;
import io.nats.client.Dispatcher;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public abstract class NatsJSONSubscriber<T> implements Subscriber<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  final JavaType envelopeType;
  final Class<T> objectType;

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private Dispatcher dispatcher;
  private String serverAddress = "nats://localhost:4222";
  private String defaultTopic = "/default";

  public NatsJSONSubscriber(Class<T> typeClass) {
    JavaType type = OBJECT_MAPPER.getTypeFactory().constructParametricType(NatsEnvelope.class, typeClass);
    this.envelopeType = type;
    this.objectType = typeClass;
  }

  public void setServerAddress(String addr) {
    serverAddress = addr;
  }

  public void setDefaultTopic(String topic) {
    defaultTopic = topic;
  }

  @Override
  public boolean isConnected() {
    return connected;
  }

  @Override
  public void subscribe(String topic) throws PubSubException {
    if (!isConnected() || dispatcher == null) {
      throw new PubSubException("Cannot subscribe - NATS connection is not ready");
    }
    dispatcher.subscribe(topic);
    log.info("Subscribed to {}", topic);
  }

  @Override
  public void unsubscribe(String topic) throws PubSubException {
    if (dispatcher != null) {
      dispatcher.unsubscribe(topic);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    try {
      if (connection != null) {
        connection.close();
      }
      connected = false;
      connection = null;
      dispatcher = null;
    } catch (Exception x) {
      throw new PubSubException("Failed to close NATS connection", x);
    }
  }

  @Override
  public void connect() throws PubSubException {
    try {
      Options options = new Options.Builder()
          .server(serverAddress)
          .maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5))
          .build();
      connection = Nats.connect(options);
      dispatcher = connection.createDispatcher(msg -> {
        try {
          NatsEnvelope<T> envelope = OBJECT_MAPPER.readValue(msg.getData(), envelopeType);
          if (envelope.getPayload() == null) {
            log.debug("Ignoring message with empty payload on {}", msg.getSubject());
            return;
          }
          if (!objectType.getSimpleName().equals(envelope.getType())) {
            log.debug("Ignoring non-target message type {}", envelope.getType());
            return;
          }
          onMessage(envelope, envelope.getPayload());
        } catch (Exception x) {
          log.error("Threw exception while handling incoming message", x);
        }
      });
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
    subscribe(defaultTopic);
  }
}
