package finos.traderx.positionservice.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import finos.traderx.positionservice.model.*;
import finos.traderx.positionservice.repository.*;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class TradeService {

	@Autowired
	TradeRepository tradeRepository;

	public List<Trade> getAllTrades() {
		List<Trade> trades = new ArrayList<>();
		this.tradeRepository.findAll().forEach(trade -> trades.add(trade));
		return trades;
	}

	public List<Trade> getTradesByAccountID(int id) {
		return this.tradeRepository.findByAccountId(id);
	}

}
