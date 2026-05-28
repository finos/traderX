package finos.traderx.messaging;

import java.util.Date;

public interface Envelope<T> {
  String getType();
  String getTopic();
  T getPayload();
  Date getDate();
  String getFrom();
}
