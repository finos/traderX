package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.TradeOrder;
import finos.traderx.tradeservice.model.TradeSide;
import finos.traderx.tradeservice.service.TradeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
@SpringBootTest
class TradeOrderControllerTest {
    @MockBean
    TradeService tradeServiceMock;
    @MockBean
    Publisher<TradeOrder> tradePublisherMock;
    TradeOrder tradeOrder;
    TradeOrderController underTest;

    @BeforeEach
    private void setUp(){
        underTest = new TradeOrderController(tradeServiceMock, tradePublisherMock);
        tradeOrder = new TradeOrder(
                "1234",
                1234,
                "MSFT",
                TradeSide.Buy,
                100
        );
    }

    @Test
    public void testValidTradeOrderCreatesTrade() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.getAccountId())).thenReturn(true);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.getSecurity())).thenReturn(true);
        ResponseEntity<TradeOrder> result = underTest.createTradeOrder(tradeOrder);
        ResponseEntity<TradeOrder> expected = ResponseEntity.ok(tradeOrder);

        assertEquals(expected, result);
        Mockito.verify(tradePublisherMock, Mockito.times(1)).publish("/trades", tradeOrder);
    }

    @Test
    public void testTradeOrderWithInvalidTickerThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.getSecurity())).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
        Mockito.verify(tradeServiceMock, Mockito.times(0)).validateAccount(tradeOrder.getAccountId());
    }

    @Test
    public void testTradeOrderWithInvalidAccountThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.getAccountId())).thenReturn(false);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.getSecurity())).thenReturn(true);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
    }

    @Test
    public void testTradeOrderWithInvalidAccountAndTickerThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.getAccountId())).thenReturn(false);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.getSecurity())).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
        Mockito.verify(tradeServiceMock, Mockito.times(0)).validateAccount(tradeOrder.getAccountId());

    }

}