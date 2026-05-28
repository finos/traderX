package finos.traderx.tradeprocessor.repository;

import finos.traderx.tradeprocessor.model.Trade;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TradeRepository extends JpaRepository<Trade, String> {
  List<Trade> findByAccountId(Integer id);
}
