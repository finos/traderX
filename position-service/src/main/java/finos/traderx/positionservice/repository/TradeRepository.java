package finos.traderx.positionservice.repository;

import finos.traderx.positionservice.model.Trade;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class TradeRepository {

  private static final RowMapper<Trade> TRADE_ROW_MAPPER = (rs, rowNum) -> {
    Trade trade = new Trade();
    trade.setId(rs.getString("ID"));
    trade.setAccountId(rs.getInt("AccountID"));
    trade.setSecurity(rs.getString("Security"));
    trade.setSide(rs.getString("Side"));
    trade.setState(rs.getString("State"));
    trade.setQuantity(rs.getInt("Quantity"));
    trade.setUpdated(rs.getTimestamp("Updated"));
    trade.setCreated(rs.getTimestamp("Created"));
    return trade;
  };

  private final JdbcTemplate jdbcTemplate;

  public TradeRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Trade> findAll() {
    return jdbcTemplate.query(
        "select ID, AccountID, Security, Side, State, Quantity, Updated, Created from Trades order by Updated desc",
        TRADE_ROW_MAPPER
    );
  }

  public List<Trade> findByAccountId(int accountId) {
    return jdbcTemplate.query(
        "select ID, AccountID, Security, Side, State, Quantity, Updated, Created from Trades where AccountID = ? order by Updated desc",
        TRADE_ROW_MAPPER,
        accountId
    );
  }
}
