package finos.traderx.tradeprocessor.controller;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.messaging.nats.NatsJSONSubscriber;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeOrder;
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
  private final Publisher<Trade> tradePublisher;
  private final Subscriber<TradeOrder> tradeSubscriber;

  public SystemController(
      Publisher<Trade> tradePublisher,
      Subscriber<TradeOrder> tradeSubscriber,
      MeterRegistry meterRegistry
  ) {
    this.tradePublisher = tradePublisher;
    this.tradeSubscriber = tradeSubscriber;

    Gauge.builder("traderx_messagebus_connected", tradePublisher, p -> p != null && p.isConnected() ? 1 : 0)
        .tag("component", "trade-processor")
        .tag("role", "publisher")
        .register(meterRegistry);
    Gauge.builder("traderx_messagebus_connected", tradeSubscriber, s -> s != null && s.isConnected() ? 1 : 0)
        .tag("component", "trade-processor")
        .tag("role", "subscriber")
        .register(meterRegistry);
  }

  @GetMapping("/health")
  public Map<String, Object> health() {
    Map<String, Object> publisher = describePublisher();
    Map<String, Object> subscriber = describeSubscriber();

    String publisherStatus = String.valueOf(publisher.get("status"));
    String subscriberStatus = String.valueOf(subscriber.get("status"));
    boolean connected = "connected".equals(publisherStatus) && "connected".equals(subscriberStatus);

    Map<String, Object> messageBus = new LinkedHashMap<>();
    messageBus.put("publisher", publisher);
    messageBus.put("subscriber", subscriber);

    Map<String, Object> payload = new LinkedHashMap<>();
    payload.put("status", connected ? "ok" : "degraded");
    payload.put("service", "trade-processor");
    payload.put("messageBus", messageBus);
    return payload;
  }

  private Map<String, Object> describePublisher() {
    Map<String, Object> payload = new LinkedHashMap<>();
    String status = tradePublisher.isConnected() ? "connected" : "disconnected";
    String address = "unknown";
    String clientId = "trade-processor-publisher";
    long uptimeSeconds = 0;

    if (tradePublisher instanceof NatsJSONPublisher<?> natsPublisher) {
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

  @SuppressWarnings("rawtypes")
  private Map<String, Object> describeSubscriber() {
    Map<String, Object> payload = new LinkedHashMap<>();
    String status = tradeSubscriber.isConnected() ? "connected" : "disconnected";
    String address = "unknown";
    String clientId = "trade-processor-subscriber";
    long uptimeSeconds = 0;

    if (tradeSubscriber instanceof NatsJSONSubscriber natsSubscriber) {
      status = natsSubscriber.getConnectionStatus();
      address = natsSubscriber.getServerAddress();
      clientId = natsSubscriber.getClientId();
      uptimeSeconds = natsSubscriber.getUptimeSeconds();
    }

    payload.put("status", status);
    payload.put("address", address);
    payload.put("clientId", clientId);
    payload.put("uptimeSeconds", uptimeSeconds);
    return payload;
  }
}
