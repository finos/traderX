package finos.traderx.tradeservice.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.slf4j.Logger;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.service.AccountValidationServiceImpl;

public class AccountValidationServiceImplTest {

    @Mock
    private RestTemplate restTemplate;

    private AccountValidationServiceImpl service;
    private static final String ACCOUNT_SERVICE_URL = "http://account-service";

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        service = new AccountValidationServiceImpl(restTemplate, ACCOUNT_SERVICE_URL);
    }

    @Test
    public void validateAccount_ExistingAccount_ReturnsTrue() {
        Account account = new Account(1, "Test Account");
        ResponseEntity<Account> response = new ResponseEntity<>(account, HttpStatus.OK);
        when(restTemplate.getForEntity(anyString(), eq(Account.class))).thenReturn(response);

        boolean result = service.validateAccount(1);

        assertTrue(result);
    }

    @Test
    public void validateAccount_ValidResponse_LogsAccountInfo() {
        Account account = new Account(1, "Test Account");
        ResponseEntity<Account> response = new ResponseEntity<>(account, HttpStatus.OK);
        when(restTemplate.getForEntity(anyString(), eq(Account.class))).thenReturn(response);

        service.validateAccount(1);

        verify(restTemplate).getForEntity(ACCOUNT_SERVICE_URL + "/account/1", Account.class);
    }

    @Test
    public void constructor_ValidParameters_InitializesCorrectly() {
        RestTemplate restTemplate = mock(RestTemplate.class);
        String serviceUrl = "http://test-url";

        AccountValidationServiceImpl service = new AccountValidationServiceImpl(restTemplate, serviceUrl);

        assertNotNull(service);
    }

    @Test
    public void validateAccount_NonexistentAccount_ReturnsFalse() {
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
            .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        boolean result = service.validateAccount(1);

        assertFalse(result);
    }

    @Test
    public void validateAccount_NullResponse_ReturnsFalse() {
        when(restTemplate.getForEntity(anyString(), eq(Account.class))).thenReturn(null);

        boolean result = service.validateAccount(1);

        assertFalse(result);
    }

    @Test
    public void validateAccount_HttpClientError_ReturnsFalse() {
        when(restTemplate.getForEntity(anyString(), eq(Account.class)))
            .thenThrow(new HttpClientErrorException(HttpStatus.INTERNAL_SERVER_ERROR));

        boolean result = service.validateAccount(1);

        assertFalse(result);
    }
}