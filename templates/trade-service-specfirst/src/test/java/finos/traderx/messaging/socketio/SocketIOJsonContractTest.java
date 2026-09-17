package finos.traderx.messaging.socketio;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import finos.traderx.tradeservice.model.TradeOrder;
import io.socket.client.Socket;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.json.JsonMapper;

class SocketIOJsonContractTest {
  @Test
  void legacyOrderAliasAndPublishedEnvelopeRemainCompatible() throws Exception {
    TradeOrder order = JsonMapper.builder().build().readValue(
        "{\"accountID\":22214,\"security\":\"IBM\",\"side\":\"Buy\",\"quantity\":10}", TradeOrder.class);
    assertEquals(22214, order.getAccountId());

    SocketIOJSONPublisher<TradeOrder> publisher = new SocketIOJSONPublisher<>() {};
    publisher.socket = mock(Socket.class);
    publisher.connected = true;
    publisher.publish("/trades", order);

    ArgumentCaptor<JSONObject> sent = ArgumentCaptor.forClass(JSONObject.class);
    verify(publisher.socket).emit(eq("publish"), sent.capture());
    JSONObject envelope = sent.getValue();
    assertEquals("/trades", envelope.getString("topic"));
    assertEquals("TradeOrder", envelope.getString("type"));
    assertInstanceOf(Number.class, envelope.get("date"));
    assertFalse(envelope.has("from"));
    JSONObject payload = envelope.getJSONObject("payload");
    assertEquals(22214, payload.getInt("accountId"));
    assertEquals("Buy", payload.getString("side"));
    assertEquals(10, payload.getInt("quantity"));
    assertFalse(payload.has("id"));
    assertFalse(payload.has("state"));
    assertFalse(payload.has("accountID"));
  }
}
