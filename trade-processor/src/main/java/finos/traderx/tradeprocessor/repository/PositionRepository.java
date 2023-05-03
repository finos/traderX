package finos.traderx.tradeprocessor.repository;


import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.PositionID;

public interface PositionRepository extends JpaRepository<Position,PositionID> {

    List<Position> findByAccountId(Integer id);
    Position findByAccountIdAndSecurity(Integer id, String security);

}
