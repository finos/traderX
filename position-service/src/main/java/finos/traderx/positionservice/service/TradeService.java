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
public class TradeService {

	@Autowired
	TradeRepository tradeRepository;

	public List<Trade> getAllTrades() {
		return StreamSupport.stream(this.tradeRepository.findAll().spliterator(), false)
			.collect(Collectors.toList());
	}

	public List<Trade> getTradesByAccountID(int id) {
		return this.tradeRepository.findByAccountId(id);
	}

}
