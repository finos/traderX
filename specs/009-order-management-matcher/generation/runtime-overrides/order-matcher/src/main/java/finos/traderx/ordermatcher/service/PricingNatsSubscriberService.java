package finos.traderx.ordermatcher.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.nats.client.Connection;
import io.nats.client.Dispatcher;
import io.nats.client.Message;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.DisposableBean;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class PricingNatsSubscriberService implements InitializingBean, DisposableBean {
    private static final Logger log = LoggerFactory.getLogger(PricingNatsSubscriberService.class);

    private final OrderMatcherService orderMatcherService;
    private final String natsAddress;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private Connection connection;
    private Dispatcher dispatcher;

    public PricingNatsSubscriberService(
        OrderMatcherService orderMatcherService,
        @Value("${nats.address:nats://${NATS_BROKER_HOST:localhost}:4222}") String natsAddress
    ) {
        this.orderMatcherService = orderMatcherService;
        this.natsAddress = natsAddress;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        Options options = new Options.Builder()
            .server(natsAddress)
            .maxReconnects(-1)
            .connectionTimeout(Duration.ofSeconds(5))
            .build();
        connection = Nats.connect(options);
        dispatcher = connection.createDispatcher(this::onMessage);
        dispatcher.subscribe("pricing.*");
        log.info("Subscribed to pricing.* on {}", natsAddress);
    }

    @Override
    public void destroy() throws Exception {
        if (dispatcher != null && connection != null) {
            connection.closeDispatcher(dispatcher);
            dispatcher = null;
        }
        if (connection != null) {
            connection.close();
            connection = null;
        }
    }

    private void onMessage(Message message) {
        try {
            String subject = message.getSubject();
            String ticker = extractTicker(subject);
            if (ticker == null) {
                return;
            }

            String raw = new String(message.getData(), StandardCharsets.UTF_8);
            JsonNode root = objectMapper.readTree(raw);
            JsonNode priceNode = root.path("payload").path("price");
            if (priceNode.isMissingNode() || priceNode.isNull()) {
                priceNode = root.path("price");
            }
            if (priceNode.isMissingNode() || priceNode.isNull()) {
                return;
            }

            BigDecimal price = new BigDecimal(priceNode.asText());
            orderMatcherService.onPriceTick(ticker, price);
        } catch (Exception ex) {
            log.warn("Failed to process pricing tick message", ex);
        }
    }

    private String extractTicker(String subject) {
        if (subject == null) {
            return null;
        }
        String prefix = "pricing.";
        if (!subject.startsWith(prefix) || subject.length() <= prefix.length()) {
            return null;
        }
        return subject.substring(prefix.length()).trim().toUpperCase(Locale.ROOT);
    }
}
