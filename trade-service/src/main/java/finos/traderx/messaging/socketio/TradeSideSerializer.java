package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import java.io.IOException;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class TradeSideSerializer extends StdSerializer<
    traderx.morphir.rulesengine.models.TradeSide.TradeSide> {
  public TradeSideSerializer() { this(null); }

  public TradeSideSerializer(
      Class<traderx.morphir.rulesengine.models.TradeSide.TradeSide> t) {
    super(t);
  }

  @Override
  public Class<traderx.morphir.rulesengine.models.TradeSide.TradeSide>
  handledType() {
    return traderx.morphir.rulesengine.models.TradeSide.TradeSide.class;
  }

  @Override
  public void
  serialize(traderx.morphir.rulesengine.models.TradeSide.TradeSide value,
            JsonGenerator gen, SerializerProvider provider) throws IOException {

    gen.writeStartObject();
    gen.writeRawValue(value.toString().toLowerCase());
    gen.writeEndObject();
  }
}
