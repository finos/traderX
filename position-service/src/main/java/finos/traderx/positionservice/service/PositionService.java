package finos.traderx.positionservice.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import finos.traderx.positionservice.model.*;
import finos.traderx.positionservice.repository.*;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class PositionService {

	@Autowired
	PositionRepository positionRepository;

	public List<Position> getAllPositions() {
		List<Position> positions = new ArrayList<>();
		this.positionRepository.findAll().forEach(account -> positions.add(account));
		return positions;
	}

	public List<Position> getPositionsByAccountID(int id) {
		return this.positionRepository.findByAccountId(id);
	}

}
