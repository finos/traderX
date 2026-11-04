package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test provides a minimal implementation of Publisher to verify interface contract.
 * This is the best approach for interface-only code, as we cannot test real logic without an implementation.
 */
class PublisherTest {
    static class DummyPublisher implements Publisher<String> {
        public void publish(String message) {}
        public void publish(String topic, String message) {}
        public boolean isConnected() { return true; }
        public void connect() {}
        public void disconnect() {}
    }
    @Test
    void testIsConnected() {
        DummyPublisher pub = new DummyPublisher();
        assertTrue(pub.isConnected());
    }
}
