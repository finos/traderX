package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import com.fasterxml.jackson.databind.node.IntNode;
import java.io.IOException;
import morphir.sdk.Int;
import morphir.sdk.Maybe.Maybe;
import traderx.morphir.rulesengine.models.DesiredAction.DesiredAction;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;
import traderx.morphir.rulesengine.models.TradeSide.TradeSide;
import traderx.morphir.rulesengine.models.TradeState.TradeState;

/**
 * Allow simple custom serialization/deserialization
 * for TradeOrder.scala
 */
public class TradeObjectCustomDeserializer extends StdDeserializer<TradeOrder> {
  public TradeObjectCustomDeserializer() { this(null); }

  public TradeObjectCustomDeserializer(Class<TradeOrder> t) { super(t); }

  @Override
  public TradeOrder deserialize(JsonParser jp, DeserializationContext ctxt)
      throws IOException, JacksonException {
    JsonNode node = jp.getCodec().readTree(jp);

    TradeSide side =
        jp.getCodec().treeToValue(node.get("side"), TradeSide.class);
    TradeState state =
        jp.getCodec().treeToValue(node.get("state"), TradeState.class);

    DesiredAction action =
        jp.getCodec().treeToValue(node.get("action"), DesiredAction.class);
    Maybe filled = jp.getCodec().treeToValue(node.get("filled"), Maybe.class);

    String id = node.get("id").asText();
    String security = node.get("security").asText();

    int accountId = (Integer)((IntNode)node.get("account_id")).numberValue();
    int quantity = (Integer)((IntNode)node.get("quantity")).numberValue();

    return new TradeOrder(id, state, security, quantity, accountId, side,
                          action, filled);
  }
}
