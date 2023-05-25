package finos.traderx.messaging;

import java.util.Date;

public interface Envelope<T> {
    public String getType();

    public String getTopic();

    public T getPayload();

    public Date getDate();

    public String getFrom();
}
