package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
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

}