package finos.traderx.tradeprocessor.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.zaxxer.hikari.HikariDataSource;
import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.PubSubException;
import finos.traderx.tradeprocessor.model.*;
import finos.traderx.tradeprocessor.repository.*;
import java.nio.file.*;
import java.sql.*;
import javax.sql.DataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.*;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest(classes = TradeCommitTest.Config.class, properties = {
    "spring.datasource.url=jdbc:h2:mem:booking;DB_CLOSE_DELAY=-1",
    "spring.datasource.username=sa", "spring.datasource.password=sa",
    "spring.jpa.hibernate.ddl-auto=none",
    "spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl"
})
class TradeCommitTest {
  @Configuration
  @EnableAutoConfiguration
  @EntityScan(basePackageClasses = Trade.class)
  @EnableJpaRepositories(basePackageClasses = TradeRepository.class)
  @Import(TradeService.class)
  static class Config {
    @Bean Publisher<Trade> tradePublisher() { return mock(Publisher.class); }
    @Bean Publisher<Position> positionPublisher() { return mock(Publisher.class); }
  }

  @Autowired TradeService service;
  @Autowired DataSource dataSource;
  @Autowired PlatformTransactionManager manager;
  @Autowired Publisher<Trade> trades;
  @Autowired Publisher<Position> positions;
  JdbcTemplate jdbc;

  @BeforeEach
  void createSchemaAndRetireCreator() throws Exception {
    reset(trades, positions);
    jdbc = new JdbcTemplate(dataSource);
    // Real schema, created on a connection that closes before any booking.
    try (Connection creator = DriverManager.getConnection("jdbc:h2:mem:booking;DB_CLOSE_DELAY=-1", "sa", "sa")) {
      creator.createStatement().execute(Files.readString(Path.of(System.getProperty("booking.schema", Files.exists(Path.of("../database/initialSchema.sql"))
          ? "../database/initialSchema.sql" : "../database-specfirst/initialSchema.sql"))));
      // Pricing overlay columns are harmless to baseline entities.
      creator.createStatement().execute("ALTER TABLE Trades ADD IF NOT EXISTS Price DECIMAL(18,3) DEFAULT 0; ALTER TABLE Positions ADD IF NOT EXISTS AverageCostBasis DECIMAL(18,3) DEFAULT 0");
    }
  }

  TradeOrder order(int quantity) {
    TradeOrder order = new TradeOrder();
    order.setAccountId(22214); order.setSecurity("META"); order.setSide(TradeSide.Buy); order.setQuantity(quantity);
    return order;
  }

  int durableQuantity() {
    return jdbc.queryForObject("SELECT Quantity FROM Positions WHERE AccountID=22214 AND Security='META'", Integer.class);
  }

  @Test
  void sequentialBookingsPublishOnlyDurableAccumulatedPositionsAfterConnectionRetirement() throws Exception {
    doAnswer(call -> {
      Position payload = call.getArgument(1);
      // Independent JDBC read at notification time must see the committed value.
      assertEquals(payload.getQuantity(), durableQuantity());
      return null;
    }).when(positions).publish(anyString(), any(Position.class));
    service.processTrade(order(7));
    dataSource.unwrap(HikariDataSource.class).getHikariPoolMXBean().softEvictConnections();
    service.processTrade(order(11));
    assertEquals(18, durableQuantity());
    assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM Trades WHERE Security='META'", Integer.class));
    verify(positions, times(2)).publish(eq("/accounts/22214/positions"), any(Position.class));
    verify(trades, times(2)).publish(eq("/accounts/22214/trades"), any(Trade.class));
  }

  @Test
  void explicitRollbackPublishesNothing() {
    new TransactionTemplate(manager).executeWithoutResult(status -> {
      service.processTrade(order(7));
      verifyNoInteractions(trades, positions);
      status.setRollbackOnly();
    });
    assertNoBooking();
  }

  @Test
  void constraintFailureAtCommitPublishesNothing() {
    assertThrows(RuntimeException.class, () -> service.processTrade(order(-1)));
    assertNoBooking();
  }

  @Test
  void publicationFailureDoesNotFailOrRepeatCommittedBookingAndOtherTopicStillRuns() throws Exception {
    doThrow(new PubSubException("feed unavailable")).when(trades).publish(anyString(), any(Trade.class));
    assertDoesNotThrow(() -> service.processTrade(order(7)));
    assertEquals(7, durableQuantity());
    verify(positions).publish(anyString(), any(Position.class));
    reset(trades, positions);
    doThrow(new IllegalStateException("disconnected")).when(positions).publish(anyString(), any(Position.class));
    assertDoesNotThrow(() -> service.processTrade(order(11)));
    assertEquals(18, durableQuantity());
    assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM Trades WHERE Security='META'", Integer.class));
  }

  @Test
  void jdbcCommitFailureDoesNotNotify() throws Exception {
    DataSource failingSource = mock(DataSource.class);
    Connection connection = mock(Connection.class);
    when(failingSource.getConnection()).thenReturn(connection);
    when(connection.getAutoCommit()).thenReturn(true);
    doThrow(new SQLException("simulated commit failure")).when(connection).commit();
    var transaction = new TransactionTemplate(
        new org.springframework.jdbc.datasource.DataSourceTransactionManager(failingSource));
    assertThrows(RuntimeException.class, () -> transaction.executeWithoutResult(status -> {
      Trade trade = new Trade(); trade.setId("failed-commit"); trade.setAccountId(22214);
      Position position = new Position(); position.setAccountId(22214);
      CommittedTradeEvents.publishAfterCommit(new TradeBookingResult(trade, position), trades, positions);
      verifyNoInteractions(trades, positions);
    }));
    verify(connection).commit();
    verifyNoInteractions(trades, positions);
  }

  @Test
  void multipleBookingsInOneTransactionCaptureSeparatePositionValues() throws Exception {
    new TransactionTemplate(manager).executeWithoutResult(status -> {
      service.processTrade(order(7));
      service.processTrade(order(11));
      verifyNoInteractions(trades, positions);
    });
    var values = org.mockito.ArgumentCaptor.forClass(Position.class);
    verify(positions, times(2)).publish(anyString(), values.capture());
    assertEquals(java.util.List.of(7, 18), values.getAllValues().stream().map(Position::getQuantity).toList());
    assertEquals(18, durableQuantity());
  }

  @Test
  void directNontransactionalCallFailsBeforeWriting() {
    var direct = new TradeService(mock(TradeRepository.class), mock(PositionRepository.class), trades, positions);
    assertThrows(IllegalStateException.class, () -> direct.processTrade(order(7)));
    assertNoBooking();
  }

  void assertNoBooking() {
    verifyNoInteractions(trades, positions);
    assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM Trades WHERE Security='META'", Integer.class));
    assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM Positions WHERE Security='META'", Integer.class));
  }
}
