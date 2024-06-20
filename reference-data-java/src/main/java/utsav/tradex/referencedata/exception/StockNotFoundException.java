package utsav.tradex.referencedata.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class StockNotFoundException extends RuntimeException {
    public StockNotFoundException(String ticker) {
        super(String.format("Stock ticker `%s` not found.", ticker));
    }
}
