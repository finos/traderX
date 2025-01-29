package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import java.io.IOException;
import morphir.sdk.Maybe.Just;
import morphir.sdk.Maybe.Maybe;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class MaybeDeserializer extends StdDeserializer<Maybe<?>> {
  public MaybeDeserializer() { this(null); }

  public MaybeDeserializer(Class<Maybe<?>> t) { super(t); }

  @Override
  public Maybe<?> deserialize(JsonParser jp, DeserializationContext ctxt)
      throws IOException, JacksonException {

    return jp.readValueAs(Just.class);
  }
}
