package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import java.io.IOException;
import morphir.sdk.Maybe.Just;
import morphir.sdk.Maybe.Maybe;
import traderx.morphir.rulesengine.models.DesiredAction.DesiredAction;

/**
 * Allow simple custom deserialization
 * for TradeState.scala
 */
public class DesiredActionDeserializer extends StdDeserializer<DesiredAction> {
  public DesiredActionDeserializer() { this(null); }

  public DesiredActionDeserializer(Class<DesiredAction> t) { super(t); }

  @Override
  public DesiredAction deserialize(JsonParser jp, DeserializationContext ctxt)
      throws IOException, JacksonException {

    String value = jp.getText().toLowerCase();
    if ("buystock".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.DesiredAction.BUYSTOCK();
    } else if ("canceltrade".contentEquals(value)) {
      return traderx.morphir.rulesengine.models.DesiredAction.CANCELTRADE();
    } else {
      throw new IOException("Could not parse state");
    }
  }
}
