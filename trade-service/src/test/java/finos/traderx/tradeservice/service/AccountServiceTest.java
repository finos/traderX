package finos.traderx.tradeservice.service;

import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Account;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AccountServiceTest {

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private AccountService accountService;

    private static final String ACCOUNT_SERVICE_URL = "http://localhost:18088";
    private static final Integer VALID_ACCOUNT_ID = 123;
    private static final Integer INVALID_ACCOUNT_ID = 999;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(accountService, "accountServiceAddress", ACCOUNT_SERVICE_URL);
        ReflectionTestUtils.setField(accountService, "fallbackEnabled", true);
        ReflectionTestUtils.setField(accountService, "restTemplate", restTemplate);
    }

    @Test
    void validateAccount_serviceAvailable_validAccount_returnsTrue() {
        // Arrange
        Account mockAccount = new Account(VALID_ACCOUNT_ID, "Test Account");
        ResponseEntity<Account> mockResponse = new ResponseEntity<>(mockAccount, HttpStatus.OK);
        when(restTemplate.getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + VALID_ACCOUNT_ID), eq(Account.class)))
                .thenReturn(mockResponse);

        // Act
        boolean result = accountService.validateAccount(VALID_ACCOUNT_ID);

        // Assert
        assertTrue(result);
        verify(restTemplate).getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + VALID_ACCOUNT_ID), eq(Account.class));
    }

    @Test
    void validateAccount_serviceAvailable_invalidAccount_returnsFalse() {
        // Arrange
        ReflectionTestUtils.setField(accountService, "fallbackEnabled", false);
        when(restTemplate.getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + INVALID_ACCOUNT_ID), eq(Account.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        // Act
        boolean result = accountService.validateAccount(INVALID_ACCOUNT_ID);

        // Assert
        assertFalse(result);
        verify(restTemplate).getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + INVALID_ACCOUNT_ID), eq(Account.class));
    }

    @Test
    void validateAccount_serviceUnavailable_fallbackEnabled_validId_returnsTrue() {
        // Arrange
        ReflectionTestUtils.setField(accountService, "fallbackEnabled", true);
        when(restTemplate.getForEntity(any(String.class), eq(Account.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act
        boolean result = accountService.validateAccount(VALID_ACCOUNT_ID);

        // Assert
        assertTrue(result);
    }

    @Test
    void validateAccount_serviceUnavailable_fallbackEnabled_invalidId_returnsFalse() {
        // Arrange
        ReflectionTestUtils.setField(accountService, "fallbackEnabled", true);
        when(restTemplate.getForEntity(any(String.class), eq(Account.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act
        boolean result = accountService.validateAccount(-1);

        // Assert
        assertFalse(result);
    }

    @Test
    void validateAccount_serviceUnavailable_fallbackDisabled_throwsException() {
        // Arrange
        ReflectionTestUtils.setField(accountService, "fallbackEnabled", false);
        when(restTemplate.getForEntity(any(String.class), eq(Account.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> accountService.validateAccount(VALID_ACCOUNT_ID));
    }

    @Test
    void validateAccount_nullAccountId_returnsFalse() {
        // Act
        boolean result = accountService.validateAccount(null);

        // Assert
        assertFalse(result);
        verifyNoInteractions(restTemplate);
    }

    @Test
    void getAccountById_serviceAvailable_returnsAccount() {
        // Arrange
        Account mockAccount = new Account(VALID_ACCOUNT_ID, "Test Account");
        ResponseEntity<Account> mockResponse = new ResponseEntity<>(mockAccount, HttpStatus.OK);
        when(restTemplate.getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + VALID_ACCOUNT_ID), eq(Account.class)))
                .thenReturn(mockResponse);

        // Act
        Account result = accountService.getAccountById(VALID_ACCOUNT_ID);

        // Assert
        assertNotNull(result);
        assertEquals(VALID_ACCOUNT_ID, result.getid());
        assertEquals("Test Account", result.getdisplayName());
    }

    @Test
    void getAccountById_accountNotFound_throwsResourceNotFoundException() {
        // Arrange
        when(restTemplate.getForEntity(eq(ACCOUNT_SERVICE_URL + "/account/" + INVALID_ACCOUNT_ID), eq(Account.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> accountService.getAccountById(INVALID_ACCOUNT_ID));
    }
}