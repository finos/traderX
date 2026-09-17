import static org.junit.jupiter.api.Assertions.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class SchemaConnectionRetirementTest {
  @Test
  void constraintsRemainValidAfterSchemaConnectionCloses() throws Exception {
    String url = "jdbc:h2:mem:" + UUID.randomUUID();
    try (Connection worker = DriverManager.getConnection(url)) {
      try (Connection creator = DriverManager.getConnection(url)) {
        creator.createStatement().execute(Files.readString(Path.of("initialSchema.sql")));
      }
      for (String side : new String[]{"Buy", "Sell", null}) {
        for (String state : new String[]{"New", "Processing", "Settled", "Cancelled", null}) {
          insertTrade(worker, side, state);
        }
        for (String status : new String[]{"NEW", "PARTIALLY_FILLED", "FILLED", "CANCELED", "REJECTED", null}) {
          insertOrder(worker, side, status);
        }
      }
      assertEquals("23513", assertThrows(SQLException.class, () -> insertTrade(worker, "invalid", "Settled")).getSQLState());
      assertEquals("23513", assertThrows(SQLException.class, () -> insertTrade(worker, "Buy", "invalid")).getSQLState());
      assertEquals("23513", assertThrows(SQLException.class, () -> insertOrder(worker, "invalid", "NEW")).getSQLState());
      assertEquals("23513", assertThrows(SQLException.class, () -> insertOrder(worker, "Buy", "invalid")).getSQLState());
    }
  }

  private void insertTrade(Connection c, String side, String state) throws SQLException {
    try (PreparedStatement s = c.prepareStatement("INSERT INTO Trades(ID, AccountID, Side, State, Quantity) VALUES (?,22214,?,?,1)")) {
      s.setString(1, UUID.randomUUID().toString()); s.setString(2, side); s.setString(3, state); s.executeUpdate();
    }
  }

  private void insertOrder(Connection c, String side, String state) throws SQLException {
    try (PreparedStatement s = c.prepareStatement("INSERT INTO OrderBook(OrderId,AccountId,Security,Side,Status,Quantity,RemainingQuantity,LimitPrice,CreatedAt,UpdatedAt) VALUES (?,22214,'META',?,?,1,1,1,NOW(),NOW())")) {
      s.setString(1, UUID.randomUUID().toString().replace("-", "")); s.setString(2, side); s.setString(3, state); s.executeUpdate();
    }
  }
}
