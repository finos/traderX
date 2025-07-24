package finos.traderx.tradeservice.service;

import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Security;
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
class ReferenceDataServiceTest {

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private ReferenceDataService referenceDataService;

    private static final String REFERENCE_DATA_SERVICE_URL = "http://localhost:18085";
    private static final String VALID_TICKER = "AAPL";
    private static final String INVALID_TICKER = "INVALID";

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(referenceDataService, "referenceDataServiceAddress", REFERENCE_DATA_SERVICE_URL);
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", true);
        ReflectionTestUtils.setField(referenceDataService, "restTemplate", restTemplate);
    }

    @Test
    void validateTicker_serviceAvailable_validTicker_returnsTrue() {
        // Arrange
        Security mockSecurity = new Security();
        ResponseEntity<Security> mockResponse = new ResponseEntity<>(mockSecurity, HttpStatus.OK);
        when(restTemplate.getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + VALID_TICKER), eq(Security.class)))
                .thenReturn(mockResponse);

        // Act
        boolean result = referenceDataService.validateTicker(VALID_TICKER);

        // Assert
        assertTrue(result);
        verify(restTemplate).getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + VALID_TICKER), eq(Security.class));
    }

    @Test
    void validateTicker_serviceAvailable_invalidTicker_returnsFalse() {
        // Arrange
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", false);
        when(restTemplate.getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + INVALID_TICKER), eq(Security.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        // Act
        boolean result = referenceDataService.validateTicker(INVALID_TICKER);

        // Assert
        assertFalse(result);
        verify(restTemplate).getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + INVALID_TICKER), eq(Security.class));
    }

    @Test
    void validateTicker_serviceUnavailable_fallbackEnabled_validTicker_returnsTrue() {
        // Arrange
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", true);
        when(restTemplate.getForEntity(any(String.class), eq(Security.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act
        boolean result = referenceDataService.validateTicker(VALID_TICKER);

        // Assert
        assertTrue(result);
    }

    @Test
    void validateTicker_serviceUnavailable_fallbackEnabled_testTicker_returnsTrue() {
        // Arrange
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", true);
        when(restTemplate.getForEntity(any(String.class), eq(Security.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act
        boolean result = referenceDataService.validateTicker("TEST");

        // Assert
        assertTrue(result);
    }

    @Test
    void validateTicker_serviceUnavailable_fallbackEnabled_invalidFormat_returnsFalse() {
        // Arrange
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", true);
        when(restTemplate.getForEntity(any(String.class), eq(Security.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act
        boolean result = referenceDataService.validateTicker("TOOLONG123");

        // Assert
        assertFalse(result);
    }

    @Test
    void validateTicker_serviceUnavailable_fallbackDisabled_throwsException() {
        // Arrange
        ReflectionTestUtils.setField(referenceDataService, "fallbackEnabled", false);
        when(restTemplate.getForEntity(any(String.class), eq(Security.class)))
                .thenThrow(new RuntimeException("Service unavailable"));

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> referenceDataService.validateTicker(VALID_TICKER));
    }

    @Test
    void validateTicker_nullTicker_returnsFalse() {
        // Act
        boolean result = referenceDataService.validateTicker(null);

        // Assert
        assertFalse(result);
        verifyNoInteractions(restTemplate);
    }

    @Test
    void validateTicker_emptyTicker_returnsFalse() {
        // Act
        boolean result = referenceDataService.validateTicker("");

        // Assert
        assertFalse(result);
        verifyNoInteractions(restTemplate);
    }

    @Test
    void getSecurityByTicker_serviceAvailable_returnsSecurity() {
        // Arrange
        Security mockSecurity = new Security();
        ResponseEntity<Security> mockResponse = new ResponseEntity<>(mockSecurity, HttpStatus.OK);
        when(restTemplate.getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + VALID_TICKER), eq(Security.class)))
                .thenReturn(mockResponse);

        // Act
        Security result = referenceDataService.getSecurityByTicker(VALID_TICKER);

        // Assert
        assertNotNull(result);
        assertEquals(mockSecurity, result);
    }

    @Test
    void getSecurityByTicker_tickerNotFound_throwsResourceNotFoundException() {
        // Arrange
        when(restTemplate.getForEntity(eq(REFERENCE_DATA_SERVICE_URL + "/stocks/" + INVALID_TICKER), eq(Security.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.NOT_FOUND));

        // Act & Assert
        assertThrows(ResourceNotFoundException.class, () -> referenceDataService.getSecurityByTicker(INVALID_TICKER));
    }
}