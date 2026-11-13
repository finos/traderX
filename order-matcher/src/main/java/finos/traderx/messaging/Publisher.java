package finos.traderx.messaging;

public interface Publisher<T> {
  void publish(T message) throws PubSubException;
  void publish(String topic, T message) throws PubSubException;
  boolean isConnected();
  void connect() throws PubSubException;
  void disconnect() throws PubSubException;
}
