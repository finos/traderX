package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * Tests for the Subscriber interface contract.
 * We create a minimal implementation to verify:
 * 1. Basic subscription functionality
 * 2. Message handling
 * 3. Connection management
 * 4. Error handling with PubSubException
 */
class SubscriberInterfaceTest {
    
    static class TestSubscriber implements Subscriber<String> {
        boolean connected = false;
        String lastTopic = null;
        String lastMessage = null;
        Envelope<?> lastEnvelope = null;
        boolean shouldThrowOnSubscribe = false;
        
        @Override
        public void subscribe(String topic) throws PubSubException {
            if (!isConnected()) {
                throw new PubSubException("Not connected");
            }
            if (shouldThrowOnSubscribe) {
                throw new PubSubException("Simulated subscribe error");
            }
            this.lastTopic = topic;
        }
        
        @Override
        public void unsubscribe(String topic) throws PubSubException {
            if (!isConnected()) {
                throw new PubSubException("Not connected");
            }
            if (lastTopic != null && lastTopic.equals(topic)) {
                lastTopic = null;
            } else {
                throw new PubSubException("Not subscribed to topic: " + topic);
            }
        }
        
        @Override
        public void onMessage(Envelope<?> envelope, String message) {
            this.lastEnvelope = envelope;
            this.lastMessage = message;
        }
        
        @Override
        public boolean isConnected() {
            return connected;
        }
        
        @Override
        public void connect() throws PubSubException {
            if (connected) {
                throw new PubSubException("Already connected");
            }
            connected = true;
        }
        
        @Override
        public void disconnect() throws PubSubException {
            if (!connected) {
                throw new PubSubException("Already disconnected");
            }
            connected = false;
            lastTopic = null;
        }
    }
    
    @Test
    void subscribe_WhenConnected_SubscribesToTopic() throws PubSubException {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        subscriber.connect();
        String topic = "/test/topic";
        
        // Act
        subscriber.subscribe(topic);
        
        // Assert
        assertEquals(topic, subscriber.lastTopic, "Should be subscribed to the topic");
    }
    
    @Test
    void subscribe_WhenDisconnected_ThrowsPubSubException() {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        String topic = "/test/topic";
        
        // Act & Assert
        assertThrows(PubSubException.class, () -> subscriber.subscribe(topic),
            "Subscribing while disconnected should throw PubSubException");
    }
    
    @Test
    void unsubscribe_FromSubscribedTopic_Succeeds() throws PubSubException {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        subscriber.connect();
        String topic = "/test/topic";
        subscriber.subscribe(topic);
        
        // Act
        subscriber.unsubscribe(topic);
        
        // Assert
        assertNull(subscriber.lastTopic, "Should be unsubscribed from the topic");
    }
    
    @Test
    void unsubscribe_FromUnsubscribedTopic_ThrowsPubSubException() throws PubSubException {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        subscriber.connect();
        
        // Act & Assert
        assertThrows(PubSubException.class, 
            () -> subscriber.unsubscribe("/nonexistent"),
            "Unsubscribing from unsubscribed topic should throw PubSubException");
    }
    
    @Test
    void onMessage_HandlesMessageAndEnvelope() {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        String message = "test message";
        TestEnvelope envelope = new TestEnvelope();
        
        // Act
        subscriber.onMessage(envelope, message);
        
        // Assert
        assertEquals(message, subscriber.lastMessage, "Message should be stored");
        assertEquals(envelope, subscriber.lastEnvelope, "Envelope should be stored");
    }
    
    @Test
    void connectionLifecycle_WorksCorrectly() throws PubSubException {
        // Arrange
        TestSubscriber subscriber = new TestSubscriber();
        
        // Act & Assert - Connection cycle
        assertFalse(subscriber.isConnected(), "Should start disconnected");
        
        subscriber.connect();
        assertTrue(subscriber.isConnected(), "Should be connected after connect()");
        
        subscriber.disconnect();
        assertFalse(subscriber.isConnected(), "Should be disconnected after disconnect()");
        assertNull(subscriber.lastTopic, "Should clear subscriptions on disconnect");
    }
    
    // Helper class for testing
    static class TestEnvelope implements Envelope<String> {
        @Override
        public String getType() { return "test"; }
        
        @Override
        public String getTopic() { return "/test"; }
        
        @Override
        public String getPayload() { return "test payload"; }
        
        @Override
        public java.util.Date getDate() { return new java.util.Date(); }
        
        @Override
        public String getFrom() { return "test-sender"; }
    }
}
