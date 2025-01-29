package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import java.io.IOException;
import morphir.sdk.Maybe.Just;
import morphir.sdk.Maybe.Maybe;
import traderx.morphir.rulesengine.models.TradeState.TradeState;

/**
 * Allow simple custom deserialization
 * for TradeState.scala
 */
public class TradeStateDeserializer extends StdDeserializer<TradeState> {
  public TradeStateDeserializer() { this(null); }

  public TradeStateDeserializer(Class<TradeState> t) { super(t); }

  @Override
  public TradeState deserialize(JsonParser jp, DeserializationContext ctxt)
      throws IOException, JacksonException {

    String value = jp.getText().toLowerCase();
    if ("new".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.TradeState.New();
    } else if ("cancelled".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.TradeState.Cancelled();
    } else {
      throw new IOException("Could not parse state");
    }
  }
}
