package finos.traderx.tradeservice.exceptions;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Tests for ResourceNotFoundException that verify:
 * 1. Exception message handling
 * 2. HTTP status annotation is present and correct
 * 3. Exception inherits from RuntimeException
 */
class ResourceNotFoundExceptionTest {

    @Test
    void constructor_SetsMessage() {
        // Arrange
        String message = "Resource XYZ not found";
        
        // Act
        ResourceNotFoundException ex = new ResourceNotFoundException(message);
        
        // Assert
        assertEquals(message, ex.getMessage(),
            "Exception should store and return the provided message");
    }

    @Test
    void class_HasCorrectAnnotation() {
        // Verify @ResponseStatus annotation is present with NOT_FOUND
        ResponseStatus annotation = ResourceNotFoundException.class.getAnnotation(ResponseStatus.class);
        assertNotNull(annotation, "Class should have @ResponseStatus annotation");
        assertEquals(HttpStatus.NOT_FOUND, annotation.value(),
            "Annotation should specify HTTP 404 NOT_FOUND status");
    }

    @Test
    void class_InheritsFromRuntimeException() {
        // Verify exception hierarchy
        assertTrue(RuntimeException.class.isAssignableFrom(ResourceNotFoundException.class),
            "Should inherit from RuntimeException for unchecked exception behavior");
    }
}
