package finos.traderx.tradeservice.controller;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * Tests for DocsController that verify:
 * 1. Root URL redirects to Swagger UI
 * This is a minimal controller that only handles redirects, so testing is straightforward
 */
class DocsControllerTest {

    @Test
    void index_ReturnsSwaggerRedirect() {
        // Arrange
        DocsController controller = new DocsController();
        
        // Act
        String viewName = controller.index();
        
        // Assert
        assertEquals("redirect:swagger-ui.html", viewName, 
            "Root URL should redirect to Swagger UI");
    }
}
