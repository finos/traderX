package finos.traderx.messaging;

public class PubSubException extends Exception {

  public PubSubException(String message) {
    super(message);
  }

  public PubSubException(String message, Throwable throwable) {
    super(message, throwable);
  }

  public PubSubException(Throwable throwable) {
    super(throwable);
  }
}
