package finos.traderx.positionservice.service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import finos.traderx.positionservice.model.*;
import finos.traderx.positionservice.repository.*;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class PositionService {

	@Autowired
	PositionRepository positionRepository;

	public List<Position> getAllPositions() {
		return StreamSupport.stream(this.positionRepository.findAll().spliterator(), false)
			.collect(Collectors.toList());
	}

	public List<Position> getPositionsByAccountID(int id) {
		return this.positionRepository.findByAccountId(id);
	}

}
