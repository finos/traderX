package finos.traderx.ordermatcher.controller;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.ordermatcher.api.OpenCountResponse;
import finos.traderx.ordermatcher.api.OrderResponse;
import finos.traderx.ordermatcher.service.OrderMatcherService;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/")
public class SystemController {
    private final OrderMatcherService orderMatcherService;
    private final Publisher<OrderResponse> orderPublisher;

    public SystemController(OrderMatcherService orderMatcherService, Publisher<OrderResponse> orderPublisher) {
        this.orderMatcherService = orderMatcherService;
        this.orderPublisher = orderPublisher;
    }

    @GetMapping({"/health", "/healthz", "/system/health"})
    public Map<String, Object> health() {
        Map<String, Object> payload = new LinkedHashMap<>(orderMatcherService.health());
        Map<String, Object> messageBus = describeMessageBus();
        payload.put("messageBus", messageBus);
        payload.put("status", "connected".equals(messageBus.get("status")) ? "ok" : "degraded");
        return payload;
    }

    @GetMapping(value = "/metrics", produces = MediaType.TEXT_PLAIN_VALUE)
    public String metrics() {
        double connectedGauge = orderPublisher != null && orderPublisher.isConnected() ? 1.0 : 0.0;
        return orderMatcherService.prometheusMetrics()
            + "# HELP traderx_messagebus_connected Message bus connectivity gauge.\n"
            + "# TYPE traderx_messagebus_connected gauge\n"
            + "traderx_messagebus_connected{component=\"order-matcher\",role=\"publisher\"} " + connectedGauge + "\n";
    }

    @GetMapping("/orders/open-count")
    public OpenCountResponse openCount() {
        return orderMatcherService.openCounts();
    }

    private Map<String, Object> describeMessageBus() {
        Map<String, Object> payload = new LinkedHashMap<>();
        String status = orderPublisher != null && orderPublisher.isConnected() ? "connected" : "disconnected";
        String address = "unknown";
        String clientId = "order-matcher-publisher";
        long uptimeSeconds = 0;

        if (orderPublisher instanceof NatsJSONPublisher<?> natsPublisher) {
            status = natsPublisher.getConnectionStatus();
            address = natsPublisher.getServerAddress();
            clientId = natsPublisher.getClientId();
            uptimeSeconds = natsPublisher.getUptimeSeconds();
        }

        payload.put("status", status);
        payload.put("address", address);
        payload.put("clientId", clientId);
        payload.put("uptimeSeconds", uptimeSeconds);
        return payload;
    }
}
