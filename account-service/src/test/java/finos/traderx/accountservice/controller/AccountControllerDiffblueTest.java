package finos.traderx.accountservice.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.service.AccountService;
import java.util.ArrayList;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.result.MockMvcResultMatchers;
import org.springframework.test.web.servlet.result.StatusResultMatchers;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

@ContextConfiguration(classes = {AccountController.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class AccountControllerDiffblueTest {
  @Autowired
  private AccountController accountController;

  @MockBean
  private AccountService accountService;

  /**
   * Test {@link AccountController#createAccount(Account)}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code Display Name}.</li>
   *   <li>Then status {@link StatusResultMatchers#isOk()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#createAccount(Account)}
   */
  @Test
  @DisplayName("Test createAccount(Account); given Account (default constructor) DisplayName is 'Display Name'; then status isOk()")
  void testCreateAccount_givenAccountDisplayNameIsDisplayName_thenStatusIsOk() throws Exception {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    when(accountService.upsertAccount(Mockito.<Account>any())).thenReturn(account);

    Account account2 = new Account();
    account2.setDisplayName("Display Name");
    account2.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account2);
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.post("/account/")
        .contentType(MediaType.APPLICATION_JSON)
        .content(content);

    // Act and Assert
    MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content().string("{\"id\":1,\"displayName\":\"Display Name\"}"));
  }

  /**
   * Test {@link AccountController#createAccount(Account)}.
   * <ul>
   *   <li>Given {@code https://example.org/example}.</li>
   *   <li>Then status four hundred fifteen.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#createAccount(Account)}
   */
  @Test
  @DisplayName("Test createAccount(Account); given 'https://example.org/example'; then status four hundred fifteen")
  void testCreateAccount_givenHttpsExampleOrgExample_thenStatusFourHundredFifteen() throws Exception {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    when(accountService.upsertAccount(Mockito.<Account>any())).thenReturn(account);
    MockHttpServletRequestBuilder postResult = MockMvcRequestBuilders.post("/account/");
    postResult.characterEncoding("https://example.org/example");

    Account account2 = new Account();
    account2.setDisplayName("Display Name");
    account2.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account2);
    MockHttpServletRequestBuilder requestBuilder = postResult.contentType(MediaType.APPLICATION_JSON).content(content);

    // Act
    ResultActions actualPerformResult = MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder);

    // Assert
    actualPerformResult.andExpect(MockMvcResultMatchers.status().is(415));
  }

  /**
   * Test {@link AccountController#createAccount(Account)}.
   * <ul>
   *   <li>Then status {@link StatusResultMatchers#isNotFound()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#createAccount(Account)}
   */
  @Test
  @DisplayName("Test createAccount(Account); then status isNotFound()")
  void testCreateAccount_thenStatusIsNotFound() throws Exception {
    // Arrange
    when(accountService.upsertAccount(Mockito.<Account>any()))
        .thenThrow(new ResourceNotFoundException("An error occurred"));

    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account);
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.post("/account/")
        .contentType(MediaType.APPLICATION_JSON)
        .content(content);

    // Act
    ResultActions actualPerformResult = MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder);

    // Assert
    actualPerformResult.andExpect(MockMvcResultMatchers.status().isNotFound())
        .andExpect(MockMvcResultMatchers.content().contentType("text/plain;charset=ISO-8859-1"))
        .andExpect(MockMvcResultMatchers.content().string("An error occurred"));
  }

  /**
   * Test {@link AccountController#updateAccount(Account)}.
   * <ul>
   *   <li>Given {@link Account} (default constructor) DisplayName is
   * {@code Display Name}.</li>
   *   <li>Then status {@link StatusResultMatchers#isOk()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#updateAccount(Account)}
   */
  @Test
  @DisplayName("Test updateAccount(Account); given Account (default constructor) DisplayName is 'Display Name'; then status isOk()")
  void testUpdateAccount_givenAccountDisplayNameIsDisplayName_thenStatusIsOk() throws Exception {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    when(accountService.upsertAccount(Mockito.<Account>any())).thenReturn(account);

    Account account2 = new Account();
    account2.setDisplayName("Display Name");
    account2.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account2);
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.put("/account/")
        .contentType(MediaType.APPLICATION_JSON)
        .content(content);

    // Act and Assert
    MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content().string("{\"id\":1,\"displayName\":\"Display Name\"}"));
  }

  /**
   * Test {@link AccountController#updateAccount(Account)}.
   * <ul>
   *   <li>Given {@code https://example.org/example}.</li>
   *   <li>Then status four hundred fifteen.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#updateAccount(Account)}
   */
  @Test
  @DisplayName("Test updateAccount(Account); given 'https://example.org/example'; then status four hundred fifteen")
  void testUpdateAccount_givenHttpsExampleOrgExample_thenStatusFourHundredFifteen() throws Exception {
    // Arrange
    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    when(accountService.upsertAccount(Mockito.<Account>any())).thenReturn(account);
    MockHttpServletRequestBuilder putResult = MockMvcRequestBuilders.put("/account/");
    putResult.characterEncoding("https://example.org/example");

    Account account2 = new Account();
    account2.setDisplayName("Display Name");
    account2.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account2);
    MockHttpServletRequestBuilder requestBuilder = putResult.contentType(MediaType.APPLICATION_JSON).content(content);

    // Act
    ResultActions actualPerformResult = MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder);

    // Assert
    actualPerformResult.andExpect(MockMvcResultMatchers.status().is(415));
  }

  /**
   * Test {@link AccountController#updateAccount(Account)}.
   * <ul>
   *   <li>Then status {@link StatusResultMatchers#isNotFound()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#updateAccount(Account)}
   */
  @Test
  @DisplayName("Test updateAccount(Account); then status isNotFound()")
  void testUpdateAccount_thenStatusIsNotFound() throws Exception {
    // Arrange
    when(accountService.upsertAccount(Mockito.<Account>any()))
        .thenThrow(new ResourceNotFoundException("An error occurred"));

    Account account = new Account();
    account.setDisplayName("Display Name");
    account.setId(1);
    String content = (new ObjectMapper()).writeValueAsString(account);
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.put("/account/")
        .contentType(MediaType.APPLICATION_JSON)
        .content(content);

    // Act
    ResultActions actualPerformResult = MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder);

    // Assert
    actualPerformResult.andExpect(MockMvcResultMatchers.status().isNotFound())
        .andExpect(MockMvcResultMatchers.content().contentType("text/plain;charset=ISO-8859-1"))
        .andExpect(MockMvcResultMatchers.content().string("An error occurred"));
  }

  /**
   * Test {@link AccountController#getAllAccount()}.
   * <ul>
   *   <li>Given {@link AccountService} {@link AccountService#getAllAccount()}
   * return {@link ArrayList#ArrayList()}.</li>
   *   <li>Then status {@link StatusResultMatchers#isOk()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); given AccountService getAllAccount() return ArrayList(); then status isOk()")
  void testGetAllAccount_givenAccountServiceGetAllAccountReturnArrayList_thenStatusIsOk() throws Exception {
    // Arrange
    when(accountService.getAllAccount()).thenReturn(new ArrayList<>());
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.get("/account/");

    // Act and Assert
    MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder)
        .andExpect(MockMvcResultMatchers.status().isOk())
        .andExpect(MockMvcResultMatchers.content().contentType("application/json"))
        .andExpect(MockMvcResultMatchers.content().string("[]"));
  }

  /**
   * Test {@link AccountController#getAllAccount()}.
   * <ul>
   *   <li>Then status {@link StatusResultMatchers#isNotFound()}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#getAllAccount()}
   */
  @Test
  @DisplayName("Test getAllAccount(); then status isNotFound()")
  void testGetAllAccount_thenStatusIsNotFound() throws Exception {
    // Arrange
    when(accountService.getAllAccount()).thenThrow(new ResourceNotFoundException("An error occurred"));
    MockHttpServletRequestBuilder requestBuilder = MockMvcRequestBuilders.get("/account/");

    // Act
    ResultActions actualPerformResult = MockMvcBuilders.standaloneSetup(accountController)
        .build()
        .perform(requestBuilder);

    // Assert
    actualPerformResult.andExpect(MockMvcResultMatchers.status().isNotFound())
        .andExpect(MockMvcResultMatchers.content().contentType("text/plain;charset=ISO-8859-1"))
        .andExpect(MockMvcResultMatchers.content().string("An error occurred"));
  }

  /**
   * Test
   * {@link AccountController#resourceNotFoundExceptionMapper(ResourceNotFoundException)}.
   * <ul>
   *   <li>Then StatusCode return {@link HttpStatus}.</li>
   * </ul>
   * <p>
   * Method under test:
   * {@link AccountController#resourceNotFoundExceptionMapper(ResourceNotFoundException)}
   */
  @Test
  @DisplayName("Test resourceNotFoundExceptionMapper(ResourceNotFoundException); then StatusCode return HttpStatus")
  void testResourceNotFoundExceptionMapper_thenStatusCodeReturnHttpStatus() {
    // Arrange and Act
    ResponseEntity<String> actualResourceNotFoundExceptionMapperResult = accountController
        .resourceNotFoundExceptionMapper(new ResourceNotFoundException("An error occurred"));

    // Assert
    HttpStatusCode statusCode = actualResourceNotFoundExceptionMapperResult.getStatusCode();
    assertTrue(statusCode instanceof HttpStatus);
    assertEquals("An error occurred", actualResourceNotFoundExceptionMapperResult.getBody());
    assertEquals(404, actualResourceNotFoundExceptionMapperResult.getStatusCodeValue());
    assertEquals(HttpStatus.NOT_FOUND, statusCode);
    assertTrue(actualResourceNotFoundExceptionMapperResult.hasBody());
    assertTrue(actualResourceNotFoundExceptionMapperResult.getHeaders().isEmpty());
  }

  /**
   * Test {@link AccountController#generalError(Exception)}.
   * <ul>
   *   <li>When {@link Exception#Exception(String)} with {@code foo}.</li>
   *   <li>Then StatusCode return {@link HttpStatus}.</li>
   * </ul>
   * <p>
   * Method under test: {@link AccountController#generalError(Exception)}
   */
  @Test
  @DisplayName("Test generalError(Exception); when Exception(String) with 'foo'; then StatusCode return HttpStatus")
  void testGeneralError_whenExceptionWithFoo_thenStatusCodeReturnHttpStatus() {
    // Arrange and Act
    ResponseEntity<String> actualGeneralErrorResult = accountController.generalError(new Exception("foo"));

    // Assert
    HttpStatusCode statusCode = actualGeneralErrorResult.getStatusCode();
    assertTrue(statusCode instanceof HttpStatus);
    assertEquals("foo", actualGeneralErrorResult.getBody());
    assertEquals(500, actualGeneralErrorResult.getStatusCodeValue());
    assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, statusCode);
    assertTrue(actualGeneralErrorResult.hasBody());
    assertTrue(actualGeneralErrorResult.getHeaders().isEmpty());
  }
}
