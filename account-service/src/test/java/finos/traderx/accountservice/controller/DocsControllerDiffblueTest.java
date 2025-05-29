package finos.traderx.accountservice.controller;

import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

@ContextConfiguration(classes = {DocsController.class})
@ExtendWith(SpringExtension.class)
class DocsControllerDiffblueTest {
  @Autowired
  private DocsController docsController;

  /**
   * Test {@link DocsController#index()}.
   * <p>
   * Method under test: {@link DocsController#index()}
   */
  @Test
  @DisplayName("Test index()")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"java.lang.String DocsController.index()"})
  void testIndex() throws Exception {
    // Arrange
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.get("/");

    // Act and Assert
    MockMvcBuilders.standaloneSetup(docsController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isFound())
        .andExpect(MockMvcResultMatchers.model().size(0))
        .andExpect(MockMvcResultMatchers.view().name("redirect:swagger-ui.html"))
        .andExpect(MockMvcResultMatchers.redirectedUrl("swagger-ui.html"));
  }
}
