package finos.traderx.positionservice.repository;


import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.model.PositionID;

public interface PositionRepository extends JpaRepository<Position,PositionID> {

    List<Position> findByAccountId(Integer id);

}
