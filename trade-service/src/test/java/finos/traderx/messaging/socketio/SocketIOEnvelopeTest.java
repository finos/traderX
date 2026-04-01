package finos.traderx.messaging.socketio;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the basic getters and setters of SocketIOEnvelope.
 * This is the best approach for a POJO/data class.
 */
class SocketIOEnvelopeTest {
    @Test
    void testSettersAndGetters() {
        SocketIOEnvelope<String> env = new SocketIOEnvelope<>("topic", "payload");
        env.setType("type");
        env.setFrom("from");
        assertEquals("topic", env.getTopic());
        assertEquals("payload", env.getPayload());
        assertEquals("type", env.getType());
        assertEquals("from", env.getFrom());
        assertNotNull(env.getDate());
    }
}
