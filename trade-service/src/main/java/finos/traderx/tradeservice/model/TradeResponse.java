package finos.traderx.tradeservice.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "Response to a trade order")
public class TradeResponse {

    @Schema(name ="Flag to indicate if the trade order was accepted for further processing or not")
    private boolean success;

    @Schema(name = "The unique identifier of the submitted trade order", example = "4e7d4734-52eb-4390-bbde-441585a92bd7")
    private String id;

    @Schema(name = "If the order failed, this message explains what was the problem")
    private String errorMessage;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

    public static TradeResponse success(String id) {
        TradeResponse tradeResponse = new TradeResponse();
        tradeResponse.setId(id);
        tradeResponse.setSuccess(true);
        return tradeResponse;
    }

    public static TradeResponse error(String message) {
        TradeResponse tradeResponse = new TradeResponse();
        tradeResponse.setSuccess(false);
        tradeResponse.setErrorMessage(message);
        return tradeResponse;
    }
}
