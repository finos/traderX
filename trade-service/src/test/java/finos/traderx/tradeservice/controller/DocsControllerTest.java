package finos.traderx.tradeservice.controller;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/**
 * This test checks the index method of DocsController.
 * This is the best approach for a simple controller redirect.
 */
class DocsControllerTest {
    @Test
    void testIndexRedirect() {
        DocsController controller = new DocsController();
        String result = controller.index();
        assertEquals("redirect:swagger-ui.html", result);
    }
}
