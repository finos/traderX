package utsav.tradex.referencedata.service;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Service;
import org.springframework.util.ResourceUtils;
import utsav.tradex.referencedata.model.Stock;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Scanner;

@Service
public class StockService {
    List<Stock> stocks;
    @PostConstruct
    private void setup() {
        stocks = new ArrayList<>();
        boolean isHeader = true;
        try {
            File csvFile = ResourceUtils.getFile("classpath:data/s-and-p-500-companies.csv");
            Scanner scanner = new Scanner(csvFile);
            while(scanner.hasNextLine()) {
                String data = scanner.nextLine();
                if(isHeader) {
                    isHeader = false;
                    continue;
                }
                String[] row = data.split(",");
                stocks.add(new Stock(row[0],row[1]));
            }
        }
        catch (Exception e){
            System.err.println("Failed to load the stocks data");
            e.printStackTrace();
        }

    }

    public List<Stock> getAllStocks() {
        return stocks;
    }

    public Optional<Stock> getStockByTicker(String ticker) {
        return stocks.stream().filter(stock -> stock.getTicker().equals(ticker)).findFirst();
    }
}
