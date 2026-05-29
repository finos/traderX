package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * Tests for the Publisher interface contract.
 * We create a minimal implementation to verify:
 * 1. Basic publishing functionality (with and without topic)
 * 2. Connection management
 * 3. Error handling with PubSubException
 */
class PublisherInterfaceTest {
    
    static class TestPublisher implements Publisher<String> {
        boolean connected = false;
        String lastMessage = null;
        String lastTopic = null;
        boolean shouldThrowOnPublish = false;
        
        @Override
        public void publish(String message) throws PubSubException {
            publish("/default", message);
        }
        
        @Override
        public void publish(String topic, String message) throws PubSubException {
            if (!isConnected()) {
                throw new PubSubException("Not connected");
            }
            if (shouldThrowOnPublish) {
                throw new PubSubException("Simulated publish error");
            }
            this.lastTopic = topic;
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
        }
    }
    
    @Test
    void publish_WhenConnected_PublishesMessage() throws PubSubException {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        publisher.connect();
        String message = "test message";
        String topic = "/test/topic";
        
        // Act
        publisher.publish(topic, message);
        
        // Assert
        assertEquals(message, publisher.lastMessage, "Message should be stored");
        assertEquals(topic, publisher.lastTopic, "Topic should be stored");
    }
    
    @Test
    void publish_WhenDisconnected_ThrowsPubSubException() {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        String message = "test message";
        
        // Act & Assert
        assertThrows(PubSubException.class, () -> publisher.publish(message),
            "Publishing while disconnected should throw PubSubException");
    }
    
    @Test
    void connect_WhenAlreadyConnected_ThrowsPubSubException() throws PubSubException {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        publisher.connect();
        
        // Act & Assert
        assertThrows(PubSubException.class, () -> publisher.connect(),
            "Connecting when already connected should throw PubSubException");
    }
    
    @Test
    void disconnect_WhenNotConnected_ThrowsPubSubException() {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        
        // Act & Assert
        assertThrows(PubSubException.class, () -> publisher.disconnect(),
            "Disconnecting when not connected should throw PubSubException");
    }
    
    @Test
    void connectionLifecycle_WorksCorrectly() throws PubSubException {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        
        // Act & Assert - Connection cycle
        assertFalse(publisher.isConnected(), "Should start disconnected");
        
        publisher.connect();
        assertTrue(publisher.isConnected(), "Should be connected after connect()");
        
        publisher.disconnect();
        assertFalse(publisher.isConnected(), "Should be disconnected after disconnect()");
    }
    
    @Test
    void publish_WithError_ThrowsPubSubException() throws PubSubException {
        // Arrange
        TestPublisher publisher = new TestPublisher();
        publisher.connect();
        publisher.shouldThrowOnPublish = true;
        
        // Act & Assert
        assertThrows(PubSubException.class, 
            () -> publisher.publish("test message"),
            "Should throw PubSubException when publish fails");
    }
}
