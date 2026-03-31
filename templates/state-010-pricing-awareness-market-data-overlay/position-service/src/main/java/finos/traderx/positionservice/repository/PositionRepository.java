package finos.traderx.positionservice.repository;

import finos.traderx.positionservice.model.Position;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class PositionRepository {

  private static final RowMapper<Position> POSITION_ROW_MAPPER = (rs, rowNum) -> {
    Position position = new Position();
    position.setAccountId(rs.getInt("AccountID"));
    position.setSecurity(rs.getString("Security"));
    position.setQuantity(rs.getInt("Quantity"));
    BigDecimal averageCostBasis = rs.getBigDecimal("AverageCostBasis");
    position.setAverageCostBasis(averageCostBasis);
    position.setUpdated(rs.getTimestamp("Updated"));
    return position;
  };

  private final JdbcTemplate jdbcTemplate;

  public PositionRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Position> findAll() {
    return jdbcTemplate.query(
        "select AccountID, Security, Quantity, AverageCostBasis, Updated from Positions order by AccountID, Security",
        POSITION_ROW_MAPPER
    );
  }

  public List<Position> findByAccountId(int accountId) {
    return jdbcTemplate.query(
        "select AccountID, Security, Quantity, AverageCostBasis, Updated from Positions where AccountID = ? order by Security",
        POSITION_ROW_MAPPER,
        accountId
    );
  }
}
