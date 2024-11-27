package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import java.io.IOException;
import morphir.sdk.Maybe.Just;
import morphir.sdk.Maybe.Maybe;
import traderx.morphir.rulesengine.models.TradeState.TradeState;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class TradeStateSerializer extends StdSerializer<TradeState> {
  public TradeStateSerializer() { this(null); }

  public TradeStateSerializer(Class<TradeState> t) { super(t); }

  @Override
  public Class<traderx.morphir.rulesengine.models.TradeState.TradeState>
  handledType() {
    return traderx.morphir.rulesengine.models.TradeState.TradeState.class;
  }

  @Override
  public void
  serialize(traderx.morphir.rulesengine.models.TradeState.TradeState value,
            JsonGenerator gen, SerializerProvider provider) throws IOException {

    gen.writeRawValue(value.toString());
  }
}
