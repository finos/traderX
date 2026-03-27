package finos.traderx.messaging;

public interface Subscriber<T> {

    public void subscribe(String topic) throws PubSubException;
    
    public void unsubscribe(String topic) throws PubSubException;

    public void onMessage(Envelope<?> envelope, T message);

    public boolean isConnected();

    public void connect() throws PubSubException;

    public void disconnect() throws PubSubException;
}
