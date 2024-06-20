package utsav.tradex.referencedata.controller;


import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import utsav.tradex.referencedata.exception.StockNotFoundException;
import utsav.tradex.referencedata.model.Stock;
import utsav.tradex.referencedata.service.StockService;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping(path = "api/stocks")
public class StockController {
    @Autowired
    private StockService stockService;

    @GetMapping(value="")
    public List<Stock> getAllStocks() {
        return stockService.getAllStocks();
    }

    @GetMapping(value = "{ticker}")
    public Stock getStockByTicker(@PathVariable String ticker) throws Exception {
        Optional<Stock> stock = stockService.getStockByTicker(ticker);
        if(stock.isEmpty()) {
            throw new StockNotFoundException(ticker);
        }
        else {
            return stock.get();
        }
    }
}
