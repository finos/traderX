package finos.traderx.messaging.socketio;

import finos.traderx.messaging.Envelope;
import java.util.Date;

public class SocketIOEnvelope<T> implements Envelope<T> {
  private String topic;
  private T payload;
  private Date date = new Date();
  private String from;
  private String type;

  public SocketIOEnvelope() {}

  public SocketIOEnvelope(String topic, T payload) {
    this.payload = payload;
    this.topic = topic;
    this.type = payload.getClass().getSimpleName();
  }

  public void setType(String type) {
    this.type = type;
  }

  public void setPayload(T payload) {
    this.payload = payload;
  }

  public void setTopic(String topic) {
    this.topic = topic;
  }

  public void setFrom(String from) {
    this.from = from;
  }

  @Override
  public String getType() {
    return type;
  }

  @Override
  public String getTopic() {
    return topic;
  }

  @Override
  public T getPayload() {
    return payload;
  }

  @Override
  public Date getDate() {
    return date;
  }

  @Override
  public String getFrom() {
    return from;
  }
}
