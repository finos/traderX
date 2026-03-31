package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public class NatsJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private String serverAddress = "nats://localhost:4222";
  private String topic = "/default";
  private String sender = "publisher";

  public void setServerAddress(String addr) {
    serverAddress = addr;
  }

  public void setTopic(String value) {
    topic = value;
  }

  public void setSender(String value) {
    sender = value;
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
      NatsEnvelope<T> envelope = new NatsEnvelope<>(topic, message, sender);
      byte[] payload = OBJECT_MAPPER.writeValueAsBytes(envelope);
      connection.publish(topic, payload);
      connection.flush(Duration.ofSeconds(2));
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
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
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
  }
}
