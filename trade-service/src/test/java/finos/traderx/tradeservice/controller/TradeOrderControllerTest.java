package finos.traderx.tradeservice.controller;

import traderx.models.TradeOrder.TradeOrder;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.service.TradeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.ResponseEntity;
import traderx.models.TradeSide;


import static org.junit.jupiter.api.Assertions.*;


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
                "1234",
                "MSFT",
                100,
                100,
                TradeSide.Buy()
        );
    }

    @Test
    public void testValidTradeOrderCreatesTrade() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.accountId())).thenReturn(true);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.security())).thenReturn(true);
        ResponseEntity<TradeOrder> result = underTest.createTradeOrder(tradeOrder);
        ResponseEntity<TradeOrder> expected = ResponseEntity.ok(tradeOrder);

        assertEquals(expected, result);
        Mockito.verify(tradePublisherMock, Mockito.times(1)).publish("/trades", tradeOrder);
    }

    @Test
    public void testTradeOrderWithInvalidTickerThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.security())).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
        Mockito.verify(tradeServiceMock, Mockito.times(0)).validateAccount(tradeOrder.accountId());
    }

    @Test
    public void testTradeOrderWithInvalidAccountThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.accountId())).thenReturn(false);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.security())).thenReturn(true);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
    }

    @Test
    public void testTradeOrderWithInvalidAccountAndTickerThrowsException() throws PubSubException {
        Mockito.doNothing().when(tradePublisherMock).publish("/trades", tradeOrder);
        Mockito.when(tradeServiceMock.validateAccount(tradeOrder.accountId())).thenReturn(false);
        Mockito.when(tradeServiceMock.validateTicker(tradeOrder.security())).thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () -> {underTest.createTradeOrder(tradeOrder);});
        Mockito.verify(tradePublisherMock, Mockito.times(0)).publish("/trades", tradeOrder);
        Mockito.verify(tradeServiceMock, Mockito.times(0)).validateAccount(tradeOrder.accountId());

    }
}