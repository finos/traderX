package finos.traderx.tradeprocessor;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.isA;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import com.diffblue.cover.annotations.MethodsUnderTest;
import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.socketio.SocketIOEnvelope;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.model.TradeSide;
import finos.traderx.tradeprocessor.model.TradeState;
import finos.traderx.tradeprocessor.service.TradeService;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class TradeFeedHandlerDiffblueTest {
  @InjectMocks
  private TradeFeedHandler tradeFeedHandler;

  @Mock
  private TradeService tradeService;

  /**
   * Test new {@link TradeFeedHandler} (default constructor).
   * <p>
   * Method under test: default or parameterless constructor of {@link TradeFeedHandler}
   */
  @Test
  @DisplayName("Test new TradeFeedHandler (default constructor)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void TradeFeedHandler.<init>()"})
  void testNewTradeFeedHandler() {
    // Arrange, Act and Assert
    assertFalse((new TradeFeedHandler()).isConnected());
  }

  /**
   * Test {@link TradeFeedHandler#onMessage(Envelope, TradeOrder)} with {@code Envelope}, {@code TradeOrder}.
   * <p>
   * Method under test: {@link TradeFeedHandler#onMessage(Envelope, TradeOrder)}
   */
  @Test
  @DisplayName("Test onMessage(Envelope, TradeOrder) with 'Envelope', 'TradeOrder'")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void TradeFeedHandler.onMessage(Envelope, TradeOrder)"})
  void testOnMessageWithEnvelopeTradeOrder() {
    // Arrange
    Trade t = new Trade();
    t.setAccountId(1);
    t.setCreated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    t.setId("42");
    t.setQuantity(1);
    t.setSecurity("Security");
    t.setSide(TradeSide.Buy);
    t.setState(TradeState.New);
    t.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position p = new Position();
    p.setAccountId(1);
    p.setQuantity(1);
    p.setSecurity("Security");
    p.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(tradeService.processTrade(Mockito.<TradeOrder>any())).thenReturn(new TradeBookingResult(t, p));
    SocketIOEnvelope<?> envelope = new SocketIOEnvelope<>();

    // Act
    tradeFeedHandler.onMessage(envelope, new TradeOrder("42", 1, "Security", TradeSide.Buy, 1));

    // Assert
    verify(tradeService).processTrade(isA(TradeOrder.class));
  }
}
