package finos.traderx.ordermatcher.api;

public class OpenCountResponse {
    private final long openOrders;
    private final long unfilledOrders;

    public OpenCountResponse(long openOrders, long unfilledOrders) {
        this.openOrders = openOrders;
        this.unfilledOrders = unfilledOrders;
    }

    public long getOpenOrders() {
        return openOrders;
    }

    public long getUnfilledOrders() {
        return unfilledOrders;
    }
}

