package finos.traderx.messaging;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import java.util.Date;

/**
 * Tests for the Envelope interface contract.
 * We create a minimal implementation to verify:
 * 1. Message metadata handling (type, topic, from, date)
 * 2. Payload handling with generics
 */
class EnvelopeInterfaceTest {
    
    static class TestEnvelope<T> implements Envelope<T> {
        private final String type;
        private final String topic;
        private final T payload;
        private final Date date;
        private final String from;
        
        TestEnvelope(String type, String topic, T payload, Date date, String from) {
            this.type = type;
            this.topic = topic;
            this.payload = payload;
            this.date = date;
            this.from = from;
        }
        
        @Override
        public String getType() {
            return type;
        }
        
        @Override
        public String getTopic() {
            return topic;
        }
        
        @Override
        public T getPayload() {
            return payload;
        }
        
        @Override
        public Date getDate() {
            return date;
        }
        
        @Override
        public String getFrom() {
            return from;
        }
    }
    
    @Test
    void envelope_WithStringPayload_HandlesAllFields() {
        // Arrange
        String type = "test-type";
        String topic = "/test/topic";
        String payload = "test payload";
        Date date = new Date();
        String from = "test-sender";
        
        // Act
        TestEnvelope<String> envelope = new TestEnvelope<>(type, topic, payload, date, from);
        
        // Assert
        assertEquals(type, envelope.getType(), "Type should match");
        assertEquals(topic, envelope.getTopic(), "Topic should match");
        assertEquals(payload, envelope.getPayload(), "Payload should match");
        assertEquals(date, envelope.getDate(), "Date should match");
        assertEquals(from, envelope.getFrom(), "Sender should match");
    }
    
    @Test
    void envelope_WithCustomPayload_HandlesGenericType() {
        // Arrange
        class CustomPayload {
            String value;
            CustomPayload(String value) { this.value = value; }
        }
        
        CustomPayload payload = new CustomPayload("test");
        Date now = new Date();
        
        // Act
        TestEnvelope<CustomPayload> envelope = new TestEnvelope<>(
            "custom", "/test", payload, now, "sender");
        
        // Assert
        assertSame(payload, envelope.getPayload(), 
            "Should handle custom payload type");
        assertEquals("test", envelope.getPayload().value,
            "Should preserve payload data");
    }
    
    @Test
    void envelope_WithNullPayload_HandlesNull() {
        // Arrange & Act
        TestEnvelope<String> envelope = new TestEnvelope<>(
            "null-test", "/test", null, new Date(), "sender");
        
        // Assert
        assertNull(envelope.getPayload(), 
            "Should handle null payload");
    }
    
    @Test
    void envelope_DateField_ReturnsOriginalDate() {
        // Arrange
        Date date = new Date();
        TestEnvelope<String> envelope = new TestEnvelope<>(
            "test", "/test", "payload", date, "sender");
        
        // Act
        Date returnedDate = envelope.getDate();
        
        // Assert
        assertSame(date, returnedDate, 
            "Should return the exact Date instance provided");
    }
}
