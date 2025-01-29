package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import java.io.IOException;
import morphir.sdk.Maybe.Just;
import morphir.sdk.Maybe.Maybe;
import traderx.morphir.rulesengine.models.TradeSide.TradeSide;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class TradeSideDeserializer extends StdDeserializer<TradeSide> {
  public TradeSideDeserializer() { this(null); }

  public TradeSideDeserializer(Class<TradeSide> t) { super(t); }

  @Override
  public TradeSide deserialize(JsonParser jp, DeserializationContext ctxt)
      throws IOException, JacksonException {

    String value = jp.getText().toLowerCase();
    if ("buy".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.TradeSide.BUY();
    } else if ("sell".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.TradeSide.SELL();
    } else {
      throw new IOException("Could not parse side");
    }
  }
}
