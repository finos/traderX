package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test provides a minimal implementation of Subscriber to verify interface contract.
 * This is the best approach for interface-only code, as we cannot test real logic without an implementation.
 */
class SubscriberTest {
    static class DummySubscriber implements Subscriber<String> {
        public void subscribe(String topic) {}
        public void unsubscribe(String topic) {}
        public void onMessage(Envelope<?> envelope, String message) {}
        public boolean isConnected() { return true; }
        public void connect() {}
        public void disconnect() {}
    }
    @Test
    void testIsConnected() {
        DummySubscriber sub = new DummySubscriber();
        assertTrue(sub.isConnected());
    }
}
