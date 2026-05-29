package finos.traderx.messaging.socketio;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the constructor and type fields of SocketIOJSONSubscriber.
 * We cannot test real socket behavior without a running server, so this is the best possible unit test.
 */
class SocketIOJSONSubscriberTest {
    static class DummySubscriber extends SocketIOJSONSubscriber<String> {
        public DummySubscriber() { super(String.class); }
        public void onMessage(finos.traderx.messaging.Envelope<?> envelope, String message) {}
    }
    @Test
    void testEnvelopeTypeAndObjectType() {
        DummySubscriber sub = new DummySubscriber();
        assertNotNull(sub.envelopeType);
        assertEquals(String.class, sub.objectType);
    }
}
