package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.tradeservice.model.TradeOrder;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/system")
public class SystemController {
  private final Publisher<TradeOrder> tradePublisher;

  public SystemController(Publisher<TradeOrder> tradePublisher, MeterRegistry meterRegistry) {
    this.tradePublisher = tradePublisher;
    Gauge.builder("traderx_messagebus_connected", tradePublisher, p -> p != null && p.isConnected() ? 1 : 0)
        .tag("component", "trade-service")
        .tag("role", "publisher")
        .register(meterRegistry);
  }

  @GetMapping("/health")
  public Map<String, Object> health() {
    Map<String, Object> messageBus = new LinkedHashMap<>();
    String status = "disconnected";
    String address = "unknown";
    String clientId = "trade-service-publisher";
    long uptimeSeconds = 0;

    if (tradePublisher instanceof NatsJSONPublisher<?> natsPublisher) {
      status = natsPublisher.getConnectionStatus();
      address = natsPublisher.getServerAddress();
      clientId = natsPublisher.getClientId();
      uptimeSeconds = natsPublisher.getUptimeSeconds();
    } else if (tradePublisher.isConnected()) {
      status = "connected";
    }

    messageBus.put("status", status);
    messageBus.put("address", address);
    messageBus.put("clientId", clientId);
    messageBus.put("uptimeSeconds", uptimeSeconds);

    Map<String, Object> payload = new LinkedHashMap<>();
    payload.put("status", "connected".equals(status) ? "ok" : "degraded");
    payload.put("service", "trade-service");
    payload.put("messageBus", messageBus);
    return payload;
  }
}
