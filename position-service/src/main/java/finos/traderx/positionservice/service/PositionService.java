package finos.traderx.positionservice.service;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.repository.PositionRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class PositionService {

  private final PositionRepository positionRepository;

  public PositionService(PositionRepository positionRepository) {
    this.positionRepository = positionRepository;
  }

  public List<Position> getAllPositions() {
    return positionRepository.findAll();
  }

  public List<Position> getPositionsByAccountID(int accountId) {
    return positionRepository.findByAccountId(accountId);
  }
}
