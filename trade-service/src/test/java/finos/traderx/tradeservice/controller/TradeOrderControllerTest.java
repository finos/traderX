package finos.traderx.tradeservice.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.model.TradeSide;
import finos.traderx.tradeservice.service.AccountService;
import finos.traderx.tradeservice.service.ReferenceDataService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(TradeOrderController.class)
class TradeOrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private Publisher<TradeOrder> tradePublisher;

    @MockBean
    private AccountService accountService;

    @MockBean
    private ReferenceDataService referenceDataService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void createTradeOrder_validTradeOrder_returnsOk() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("1", 123, "AAPL", TradeSide.Buy, 100);

        when(referenceDataService.validateTicker("AAPL")).thenReturn(true);
        when(accountService.validateAccount(123)).thenReturn(true);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.security").value("AAPL"))
                .andExpect(jsonPath("$.accountId").value(123));

        verify(referenceDataService).validateTicker("AAPL");
        verify(accountService).validateAccount(123);
        verify(tradePublisher).publish(eq("/trades"), any(TradeOrder.class));
    }

    @Test
    void createTradeOrder_invalidTicker_returnsNotFound() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("2", 123, "INVALID", TradeSide.Buy, 100);

        when(referenceDataService.validateTicker("INVALID")).thenReturn(false);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        verify(referenceDataService).validateTicker("INVALID");
        verifyNoInteractions(accountService);
        verifyNoInteractions(tradePublisher);
    }

    @Test
    void createTradeOrder_invalidAccount_returnsNotFound() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("3", 999, "AAPL", TradeSide.Buy, 100);

        when(referenceDataService.validateTicker("AAPL")).thenReturn(true);
        when(accountService.validateAccount(999)).thenReturn(false);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isNotFound());

        verify(referenceDataService).validateTicker("AAPL");
        verify(accountService).validateAccount(999);
        verifyNoInteractions(tradePublisher);
    }

    @Test
    void createTradeOrder_serviceUnavailable_fallbackEnabled_returnsOk() throws Exception {
        // Arrange
        TradeOrder tradeOrder = new TradeOrder("4", 123, "TEST", TradeSide.Buy, 100);

        // Simulate services being unavailable but fallback working
        when(referenceDataService.validateTicker("TEST")).thenReturn(true);
        when(accountService.validateAccount(123)).thenReturn(true);

        // Act & Assert
        mockMvc.perform(post("/trade/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(tradeOrder)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.security").value("TEST"))
                .andExpect(jsonPath("$.accountId").value(123));

        verify(referenceDataService).validateTicker("TEST");
        verify(accountService).validateAccount(123);
        verify(tradePublisher).publish(eq("/trades"), any(TradeOrder.class));
    }
}