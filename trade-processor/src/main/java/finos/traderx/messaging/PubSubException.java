package finos.traderx.messaging;

public class PubSubException extends Exception {

    public PubSubException(String str){ super(str); }
    public PubSubException(String str, Throwable t){ super(str,t); }
    public PubSubException(Throwable t){ super(t); }
}
