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
import traderx.morphir.rulesengine.models.TradeSide.TradeSide;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class TradeSideSerializer extends StdSerializer<TradeSide> {
  public TradeSideSerializer() { this(null); }

  public TradeSideSerializer(Class<TradeSide> t) { super(t); }

  @Override
  public Class<traderx.morphir.rulesengine.models.TradeSide.TradeSide>
  handledType() {
    return traderx.morphir.rulesengine.models.TradeSide.TradeSide.class;
  }

  @Override
  public void
  serialize(traderx.morphir.rulesengine.models.TradeSide.TradeSide value,
            JsonGenerator gen, SerializerProvider provider) throws IOException {

    gen.writeRawValue(value.toString());
  }
}
