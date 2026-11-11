package finos.traderx.messaging;

public interface Subscriber<T> {
  void subscribe(String topic) throws PubSubException;
  void unsubscribe(String topic) throws PubSubException;
  void onMessage(Envelope<?> envelope, T message);
  boolean isConnected();
  void connect() throws PubSubException;
  void disconnect() throws PubSubException;
}
