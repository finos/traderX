package finos.traderx.tradeservice;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.model.TradeOrder;

/**
 * This test checks that the tradePublisher bean is created.
 * We use ReflectionTestUtils to inject the address, as Spring injection is not available in a plain unit test.
 * This is the best approach for a simple config class.
 */
class PubSubConfigTest {
    @Test
    void tradePublisherReturnsPublisher() {
        PubSubConfig config = new PubSubConfig();
        ReflectionTestUtils.setField(config, "tradeFeedAddress", "localhost:1234");
        Publisher<TradeOrder> publisher = config.tradePublisher();
        assertNotNull(publisher);
    }
}
