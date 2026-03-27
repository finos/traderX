package finos.traderx.messaging;

public interface Publisher<T> {
    public void publish(T message) throws PubSubException;

    public void publish(String topic, T message) throws PubSubException;

    public boolean isConnected();

    public void connect() throws PubSubException;
    
    public void disconnect() throws PubSubException;
}
