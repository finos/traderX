package finos.traderx.tradeprocessor.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isA;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.model.TradeSide;
import finos.traderx.tradeprocessor.model.TradeState;
import finos.traderx.tradeprocessor.repository.PositionRepository;
import finos.traderx.tradeprocessor.repository.TradeRepository;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Date;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {TradeService.class})
@ExtendWith(SpringExtension.class)
@DisabledInAotMode
class TradeServiceDiffblueTest {
  @MockBean
  private PositionRepository positionRepository;

  @MockBean
  private Publisher<Position> publisher;

  @MockBean
  private Publisher<Trade> publisher2;

  @MockBean
  private TradeRepository tradeRepository;

  @Autowired
  private TradeService tradeService;

  /**
   * Test {@link TradeService#processTrade(TradeOrder)}.
   * <ul>
   *   <li>Then return Trade Side is {@code Buy}.</li>
   * </ul>
   * <p>
   * Method under test: {@link TradeService#processTrade(TradeOrder)}
   */
  @Test
  @DisplayName("Test processTrade(TradeOrder); then return Trade Side is 'Buy'")
  void testProcessTrade_thenReturnTradeSideIsBuy() throws PubSubException {
    // Arrange
    doNothing().when(publisher).publish(Mockito.<String>any(), Mockito.<Position>any());

    Position position = new Position();
    position.setAccountId(1);
    position.setQuantity(1);
    position.setSecurity("Security");
    position.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position position2 = new Position();
    position2.setAccountId(1);
    position2.setQuantity(1);
    position2.setSecurity("Security");
    position2.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(positionRepository.findByAccountIdAndSecurity(Mockito.<Integer>any(), Mockito.<String>any()))
        .thenReturn(position);
    when(positionRepository.save(Mockito.<Position>any())).thenReturn(position2);
    doNothing().when(publisher2).publish(Mockito.<String>any(), Mockito.<Trade>any());

    Trade trade = new Trade();
    trade.setAccountId(1);
    trade.setCreated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    trade.setId("42");
    trade.setQuantity(1);
    trade.setSecurity("Security");
    trade.setSide(TradeSide.Buy);
    trade.setState(TradeState.New);
    trade.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(tradeRepository.save(Mockito.<Trade>any())).thenReturn(trade);

    // Act
    TradeBookingResult actualProcessTradeResult = tradeService
        .processTrade(new TradeOrder("42", 1, "Security", TradeSide.Buy, 1));

    // Assert
    verify(publisher).publish(eq("/accounts/1/positions"), isA(Position.class));
    verify(publisher2).publish(eq("/accounts/1/trades"), isA(Trade.class));
    verify(positionRepository).findByAccountIdAndSecurity(eq(1), eq("Security"));
    verify(positionRepository).save(isA(Position.class));
    verify(tradeRepository, atLeast(1)).save(isA(Trade.class));
    Trade trade2 = actualProcessTradeResult.getTrade();
    assertEquals("Security", trade2.getSecurity());
    assertEquals(1, trade2.getAccountId().intValue());
    assertEquals(1, trade2.getQuantity().intValue());
    assertEquals(TradeSide.Buy, trade2.getSide());
    assertEquals(TradeState.Settled, trade2.getState());
    assertSame(position, actualProcessTradeResult.getPosition());
  }

  /**
   * Test {@link TradeService#processTrade(TradeOrder)}.
   * <ul>
   *   <li>Then return Trade Side is {@code null}.</li>
   * </ul>
   * <p>
   * Method under test: {@link TradeService#processTrade(TradeOrder)}
   */
  @Test
  @DisplayName("Test processTrade(TradeOrder); then return Trade Side is 'null'")
  void testProcessTrade_thenReturnTradeSideIsNull() throws PubSubException {
    // Arrange
    doNothing().when(publisher).publish(Mockito.<String>any(), Mockito.<Position>any());

    Position position = new Position();
    position.setAccountId(1);
    position.setQuantity(1);
    position.setSecurity("Security");
    position.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));

    Position position2 = new Position();
    position2.setAccountId(1);
    position2.setQuantity(1);
    position2.setSecurity("Security");
    position2.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(positionRepository.findByAccountIdAndSecurity(Mockito.<Integer>any(), Mockito.<String>any()))
        .thenReturn(position);
    when(positionRepository.save(Mockito.<Position>any())).thenReturn(position2);
    doNothing().when(publisher2).publish(Mockito.<String>any(), Mockito.<Trade>any());

    Trade trade = new Trade();
    trade.setAccountId(1);
    trade.setCreated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    trade.setId("42");
    trade.setQuantity(1);
    trade.setSecurity("Security");
    trade.setSide(TradeSide.Buy);
    trade.setState(TradeState.New);
    trade.setUpdated(Date.from(LocalDate.of(1970, 1, 1).atStartOfDay().atZone(ZoneOffset.UTC).toInstant()));
    when(tradeRepository.save(Mockito.<Trade>any())).thenReturn(trade);

    // Act
    TradeBookingResult actualProcessTradeResult = tradeService
        .processTrade(new TradeOrder("42", 1, "Security", null, 1));

    // Assert
    verify(publisher).publish(eq("/accounts/1/positions"), isA(Position.class));
    verify(publisher2).publish(eq("/accounts/1/trades"), isA(Trade.class));
    verify(positionRepository).findByAccountIdAndSecurity(eq(1), eq("Security"));
    verify(positionRepository).save(isA(Position.class));
    verify(tradeRepository, atLeast(1)).save(isA(Trade.class));
    Trade trade2 = actualProcessTradeResult.getTrade();
    assertEquals("Security", trade2.getSecurity());
    assertNull(trade2.getSide());
    assertEquals(1, trade2.getAccountId().intValue());
    assertEquals(1, trade2.getQuantity().intValue());
    assertEquals(TradeState.Settled, trade2.getState());
    assertSame(position, actualProcessTradeResult.getPosition());
  }
}
