package finos.traderx.ordermatcher.service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.ordermatcher.api.OpenCountResponse;
import finos.traderx.ordermatcher.api.OrderCreateRequest;
import finos.traderx.ordermatcher.api.OrderResponse;
import finos.traderx.ordermatcher.model.OrderRecord;
import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderStatus;
import finos.traderx.ordermatcher.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.locks.ReentrantLock;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.springframework.http.HttpStatus.BAD_GATEWAY;
import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.NOT_FOUND;

@Service
public class OrderMatcherService {
    private static final Logger log = LoggerFactory.getLogger(OrderMatcherService.class);
    private static final String APP_NAME = "traderx-order-matcher";
    private static final Pattern ORDER_ID_PATTERN = Pattern.compile("^ord-013-(\\d{4,})$");
    private static final String ALL_ORDERS_TOPIC = "/orders";
    private static final Set<OrderStatus> OPEN_STATUSES = Set.of(OrderStatus.NEW, OrderStatus.PARTIALLY_FILLED);

    private final OrderRepository orderRepository;
    private final Publisher<OrderResponse> orderPublisher;
    private final RestTemplate restTemplate;
    private final boolean seedEnabled;
    private final String priceServiceUrl;
    private final String tradeServiceUrl;
    private final int fillFullThreshold;
    private final long matcherTickMs;

    private final Instant startedAt = Instant.now();
    private final AtomicInteger nextOrderSequence = new AtomicInteger(1);
    private final AtomicLong matcherTicks = new AtomicLong(0);
    private final AtomicLong autoFillAttempts = new AtomicLong(0);
    private final AtomicLong autoFillSuccess = new AtomicLong(0);
    private final AtomicLong tradeSubmitFailures = new AtomicLong(0);
    private final Map<String, AtomicLong> eventCounters = new ConcurrentHashMap<>();
    private final Map<String, BigDecimal> lastPrices = new ConcurrentHashMap<>();
    private final ReentrantLock orderMutationLock = new ReentrantLock();
    private volatile Instant lastTickAt;

    public OrderMatcherService(
        OrderRepository orderRepository,
        Publisher<OrderResponse> orderPublisher,
        RestTemplate restTemplate,
        @Value("${order.matcher.seed-enabled:true}") boolean seedEnabled,
        @Value("${order.matcher.price-service-url:http://price-publisher:18100}") String priceServiceUrl,
        @Value("${order.matcher.trade-service-url:http://trade-service:18092/trade/}") String tradeServiceUrl,
        @Value("${order.matcher.tick-ms:1000}") long matcherTickMs,
        @Value("${order.matcher.fill-full-threshold:1000}") int fillFullThreshold
    ) {
        this.orderRepository = orderRepository;
        this.orderPublisher = orderPublisher;
        this.restTemplate = restTemplate;
        this.seedEnabled = seedEnabled;
        this.priceServiceUrl = trimTrailingSlash(priceServiceUrl);
        this.tradeServiceUrl = tradeServiceUrl;
        this.matcherTickMs = Math.max(100, matcherTickMs);
        this.fillFullThreshold = Math.max(1, fillFullThreshold);
        initializeCounters();
        initializeData();
    }

    @Scheduled(fixedDelayString = "${order.matcher.tick-ms:1000}")
    public void runMatcherTick() {
        List<OrderRecord> openOrders = orderRepository.findAllByOrderByUpdatedAtDesc().stream()
            .filter(this::isOpen)
            .filter(order -> order.getRemainingQuantity() != null && order.getRemainingQuantity() > 0)
            .toList();

        for (OrderRecord order : openOrders) {
            BigDecimal marketPrice = lastPrices.get(order.getSecurity());
            if (marketPrice != null) {
                tryAutoFill(order.getOrderId(), marketPrice);
            }
        }
        matcherTicks.incrementAndGet();
        lastTickAt = Instant.now();
    }

    public void onPriceTick(String ticker, BigDecimal marketPrice) {
        if (!StringUtils.hasText(ticker) || marketPrice == null) {
            return;
        }

        String normalizedTicker = ticker.trim().toUpperCase(Locale.ROOT);
        BigDecimal normalizedPrice = roundPrice(marketPrice);
        if (normalizedPrice == null) {
            return;
        }
        lastPrices.put(normalizedTicker, normalizedPrice);

        List<String> openOrderIds = orderRepository.findAllByOrderByUpdatedAtDesc().stream()
            .filter(this::isOpen)
            .filter(order -> order.getRemainingQuantity() != null && order.getRemainingQuantity() > 0)
            .filter(order -> normalizedTicker.equals(order.getSecurity()))
            .map(OrderRecord::getOrderId)
            .toList();

        for (String orderId : openOrderIds) {
            tryAutoFill(orderId, normalizedPrice);
        }
    }

    public List<OrderResponse> listOrders(String statusFilter, Integer accountIdFilter) {
        String normalizedStatus = StringUtils.hasText(statusFilter) ? statusFilter.trim().toLowerCase(Locale.ROOT) : "open";
        List<OrderRecord> rows = new ArrayList<>(orderRepository.findAllByOrderByUpdatedAtDesc());

        rows = rows.stream()
            .filter(order -> filterByStatus(order, normalizedStatus))
            .filter(order -> accountIdFilter == null || order.getAccountId().equals(accountIdFilter))
            .sorted(Comparator.comparing(OrderRecord::getUpdatedAt).reversed())
            .toList();

        return rows.stream()
            .map(order -> OrderResponse.from(order, lastPrices.get(order.getSecurity())))
            .toList();
    }

    public OrderResponse getOrder(String orderId) {
        OrderRecord order = findOrder(orderId);
        return OrderResponse.from(order, lastPrices.get(order.getSecurity()));
    }

    public OrderResponse createOrder(OrderCreateRequest request) {
        validateCreateRequest(request);
        orderMutationLock.lock();
        try {
            OrderRecord order = new OrderRecord();
            order.setOrderId(nextOrderId());
            order.setAccountId(request.getAccountId());
            order.setSecurity(request.getSecurity().trim().toUpperCase(Locale.ROOT));
            order.setSide(request.getSide());
            order.setQuantity(request.getQuantity());
            order.setRemainingQuantity(request.getQuantity());
            order.setLimitPrice(roundPrice(request.getLimitPrice()));
            order.setStatus(OrderStatus.NEW);
            order.setCreatedAt(Instant.now());
            order.setUpdatedAt(order.getCreatedAt());
            OrderRecord saved = orderRepository.save(order);
            incrementEvent("create");
            return OrderResponse.from(saved, lastPrices.get(saved.getSecurity()));
        } finally {
            orderMutationLock.unlock();
        }
    }

    public OrderResponse cancelOrder(String orderId) {
        orderMutationLock.lock();
        try {
            OrderRecord order = findOrder(orderId);
            if (isOpen(order)) {
                order.setStatus(OrderStatus.CANCELED);
                order.setRemainingQuantity(0);
                order.setUpdatedAt(Instant.now());
                orderRepository.save(order);
                incrementEvent("cancel");
            }
            return OrderResponse.from(order, lastPrices.get(order.getSecurity()));
        } finally {
            orderMutationLock.unlock();
        }
    }

    public OrderResponse forceFillOrder(String orderId) {
        orderMutationLock.lock();
        try {
            OrderRecord order = findOrder(orderId);
            if (!isOpen(order) || order.getRemainingQuantity() == null || order.getRemainingQuantity() <= 0) {
                return OrderResponse.from(order, lastPrices.get(order.getSecurity()));
            }
            int fillQty = order.getRemainingQuantity();
            BigDecimal marketPrice = Optional.ofNullable(lastPrices.get(order.getSecurity()))
                .orElse(order.getLimitPrice());
            if (!submitTrade(order, fillQty)) {
                tradeSubmitFailures.incrementAndGet();
                incrementEvent("reject");
                throw new ResponseStatusException(BAD_GATEWAY, "failed to submit trade for force-fill");
            }
            applyFill(order, fillQty, marketPrice, true);
            orderRepository.save(order);
            return OrderResponse.from(order, lastPrices.get(order.getSecurity()));
        } finally {
            orderMutationLock.unlock();
        }
    }

    public OpenCountResponse openCounts() {
        long openOrders = orderRepository.countByStatusIn(OPEN_STATUSES);
        long unfilledOrders = orderRepository.countByStatusInAndRemainingQuantityGreaterThan(OPEN_STATUSES, 0);
        return new OpenCountResponse(openOrders, unfilledOrders);
    }

    public Map<String, Object> health() {
        OpenCountResponse openCount = openCounts();
        Map<String, Object> matcher = new LinkedHashMap<>();
        matcher.put("tickMs", matcherTickMs);
        matcher.put("ticks", matcherTicks.get());
        matcher.put("lastTickAt", lastTickAt);
        matcher.put("autoFillAttempts", autoFillAttempts.get());
        matcher.put("autoFillSuccess", autoFillSuccess.get());
        matcher.put("tradeSubmitFailures", tradeSubmitFailures.get());
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("status", "ok");
        payload.put("service", APP_NAME);
        payload.put("uptimeSeconds", Math.max(0, Instant.now().getEpochSecond() - startedAt.getEpochSecond()));
        payload.put("priceServiceUrl", priceServiceUrl);
        payload.put("tradeServiceUrl", tradeServiceUrl);
        payload.put("matcher", matcher);
        payload.put("openOrders", openCount.getOpenOrders());
        payload.put("unfilledOrders", openCount.getUnfilledOrders());
        return payload;
    }

    public String prometheusMetrics() {
        long openOrders = orderRepository.countByStatusIn(OPEN_STATUSES);
        long unfilledOrders = orderRepository.countByStatusInAndRemainingQuantityGreaterThan(OPEN_STATUSES, 0);
        long buyPending = orderRepository.countByStatusInAndSide(OPEN_STATUSES, OrderSide.Buy);
        long sellPending = orderRepository.countByStatusInAndSide(OPEN_STATUSES, OrderSide.Sell);
        StringBuilder sb = new StringBuilder();
        sb.append("# HELP traderx_orders_open_total Total open orders (NEW + PARTIALLY_FILLED).\n");
        sb.append("# TYPE traderx_orders_open_total gauge\n");
        sb.append("traderx_orders_open_total ").append(openOrders).append('\n');
        sb.append("# HELP traderx_orders_unfilled_total Total orders with remaining quantity > 0.\n");
        sb.append("# TYPE traderx_orders_unfilled_total gauge\n");
        sb.append("traderx_orders_unfilled_total ").append(unfilledOrders).append('\n');
        sb.append("# HELP traderx_orders_pending_by_side Pending orders grouped by side.\n");
        sb.append("# TYPE traderx_orders_pending_by_side gauge\n");
        sb.append("traderx_orders_pending_by_side{side=\"Buy\"} ").append(buyPending).append('\n');
        sb.append("traderx_orders_pending_by_side{side=\"Sell\"} ").append(sellPending).append('\n');
        sb.append("# HELP traderx_order_events_total Order lifecycle events.\n");
        sb.append("# TYPE traderx_order_events_total counter\n");
        for (String event : List.of("create", "partial_fill", "fill", "cancel", "reject", "force_fill")) {
            sb.append("traderx_order_events_total{event=\"").append(event).append("\"} ")
                .append(counterValue(event)).append('\n');
        }
        sb.append("# HELP traderx_order_matcher_ticks_total Matcher tick executions.\n");
        sb.append("# TYPE traderx_order_matcher_ticks_total counter\n");
        sb.append("traderx_order_matcher_ticks_total ").append(matcherTicks.get()).append('\n');
        sb.append("# HELP traderx_order_autofill_attempts_total Auto-fill attempts.\n");
        sb.append("# TYPE traderx_order_autofill_attempts_total counter\n");
        sb.append("traderx_order_autofill_attempts_total ").append(autoFillAttempts.get()).append('\n');
        sb.append("# HELP traderx_order_autofill_success_total Auto-fill successful fills/partial-fills.\n");
        sb.append("# TYPE traderx_order_autofill_success_total counter\n");
        sb.append("traderx_order_autofill_success_total ").append(autoFillSuccess.get()).append('\n');
        sb.append("# HELP traderx_order_trade_submit_failures_total Trade submit failures on fill attempts.\n");
        sb.append("# TYPE traderx_order_trade_submit_failures_total counter\n");
        sb.append("traderx_order_trade_submit_failures_total ").append(tradeSubmitFailures.get()).append('\n');
        sb.append("# HELP traderx_order_match_latency_seconds Matcher latency histogram.\n");
        sb.append("# TYPE traderx_order_match_latency_seconds histogram\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"0.01\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"0.05\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"0.1\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"0.25\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"0.5\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"1\"} 0\n");
        sb.append("traderx_order_match_latency_seconds_bucket{le=\"+Inf\"} ").append(matcherTicks.get()).append('\n');
        sb.append("traderx_order_match_latency_seconds_sum 0\n");
        sb.append("traderx_order_match_latency_seconds_count ").append(matcherTicks.get()).append('\n');
        return sb.toString();
    }

    private void tryAutoFill(String orderId, BigDecimal marketPrice) {
        OrderRecord order = orderRepository.findById(orderId).orElse(null);
        if (order == null || !isOpen(order) || order.getRemainingQuantity() == null || order.getRemainingQuantity() <= 0) {
            return;
        }
        if (marketPrice == null) {
            return;
        }
        if (!isInTheMoney(order, marketPrice)) {
            return;
        }
        autoFillAttempts.incrementAndGet();
        int remaining = order.getRemainingQuantity();
        int fillQty = remaining < fillFullThreshold ? remaining : Math.max(1, (remaining + 1) / 2);

        orderMutationLock.lock();
        try {
            OrderRecord liveOrder = orderRepository.findById(orderId).orElse(null);
            if (liveOrder == null || !isOpen(liveOrder) || liveOrder.getRemainingQuantity() == null || liveOrder.getRemainingQuantity() <= 0) {
                return;
            }
            if (!submitTrade(liveOrder, fillQty)) {
                tradeSubmitFailures.incrementAndGet();
                incrementEvent("reject");
                liveOrder.setUpdatedAt(Instant.now());
                orderRepository.save(liveOrder);
                return;
            }
            applyFill(liveOrder, fillQty, marketPrice, false);
            orderRepository.save(liveOrder);
            publishOrderUpdate(liveOrder);
            autoFillSuccess.incrementAndGet();
        } finally {
            orderMutationLock.unlock();
        }
    }

    public void publishOrderUpdate(OrderResponse order) {
        if (order == null || order.getAccountId() == null) {
            return;
        }
        String accountTopic = "/accounts/" + order.getAccountId() + "/orders";
        try {
            orderPublisher.publish(accountTopic, order);
            orderPublisher.publish(ALL_ORDERS_TOPIC, order);
        } catch (PubSubException ex) {
            log.warn("Unable to publish order update for {} on {}/{}", order.getOrderId(), accountTopic, ALL_ORDERS_TOPIC, ex);
        }
    }

    private void publishOrderUpdate(OrderRecord order) {
        publishOrderUpdate(OrderResponse.from(order, lastPrices.get(order.getSecurity())));
    }

    private void applyFill(OrderRecord order, int fillQty, BigDecimal executionPrice, boolean forceFill) {
        int remainingBefore = order.getRemainingQuantity() == null ? 0 : order.getRemainingQuantity();
        int remainingAfter = Math.max(0, remainingBefore - fillQty);
        order.setRemainingQuantity(remainingAfter);
        order.setLastExecutionPrice(roundPrice(executionPrice));
        order.setLastFillQuantity(fillQty);
        order.setUpdatedAt(Instant.now());

        if (remainingAfter == 0) {
            order.setStatus(OrderStatus.FILLED);
            incrementEvent("fill");
        } else {
            order.setStatus(OrderStatus.PARTIALLY_FILLED);
            incrementEvent("partial_fill");
        }
        if (forceFill) {
            incrementEvent("force_fill");
        }
    }

    private boolean submitTrade(OrderRecord order, int quantity) {
        try {
            Map<String, Object> payload = Map.of(
                "security", order.getSecurity(),
                "quantity", quantity,
                "accountId", order.getAccountId(),
                "side", order.getSide().name()
            );
            ResponseEntity<Map> response = restTemplate.postForEntity(tradeServiceUrl, payload, Map.class);
            return response.getStatusCode().is2xxSuccessful();
        } catch (Exception e) {
            return false;
        }
    }

    private boolean filterByStatus(OrderRecord order, String statusFilter) {
        if ("open".equals(statusFilter)) {
            return isOpen(order);
        }
        if ("all".equals(statusFilter)) {
            return true;
        }
        try {
            OrderStatus status = OrderStatus.valueOf(statusFilter.toUpperCase(Locale.ROOT));
            return order.getStatus() == status;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private boolean isOpen(OrderRecord order) {
        return OPEN_STATUSES.contains(order.getStatus());
    }

    private boolean isInTheMoney(OrderRecord order, BigDecimal marketPrice) {
        if (order.getLimitPrice() == null || marketPrice == null || order.getSide() == null) {
            return false;
        }
        return switch (order.getSide()) {
            case Buy -> marketPrice.compareTo(order.getLimitPrice()) <= 0;
            case Sell -> marketPrice.compareTo(order.getLimitPrice()) >= 0;
        };
    }

    private void validateCreateRequest(OrderCreateRequest request) {
        if (request == null
            || request.getAccountId() == null || request.getAccountId() <= 0
            || !StringUtils.hasText(request.getSecurity())
            || request.getSide() == null
            || request.getQuantity() == null || request.getQuantity() <= 0
            || request.getLimitPrice() == null || request.getLimitPrice().compareTo(BigDecimal.ZERO) <= 0) {
            throw new ResponseStatusException(BAD_REQUEST, "invalid order payload");
        }
    }

    private String nextOrderId() {
        return String.format("ord-013-%04d", nextOrderSequence.getAndIncrement());
    }

    private OrderRecord findOrder(String orderId) {
        return orderRepository.findById(orderId)
            .orElseThrow(() -> new ResponseStatusException(NOT_FOUND, "order not found"));
    }

    private BigDecimal roundPrice(BigDecimal input) {
        if (input == null) {
            return null;
        }
        return input.setScale(3, RoundingMode.HALF_UP);
    }

    private void initializeData() {
        if (seedEnabled && orderRepository.count() == 0) {
            List<OrderRecord> seed = List.of(
                seedOrder("ord-013-0001", 22214, "IBM", OrderSide.Buy, 1800, 1800, bd("187.250"), OrderStatus.NEW),
                seedOrder("ord-013-0002", 22214, "MSFT", OrderSide.Sell, 900, 650, bd("412.000"), OrderStatus.PARTIALLY_FILLED),
                seedOrder("ord-013-0003", 44044, "JPM", OrderSide.Buy, 1200, 1200, bd("191.500"), OrderStatus.NEW),
                seedOrder("ord-013-0004", 52355, "GS", OrderSide.Sell, 300, 0, bd("498.000"), OrderStatus.FILLED),
                seedOrder("ord-013-0005", 10031, "NVDA", OrderSide.Buy, 450, 450, bd("905.125"), OrderStatus.NEW),
                seedOrder("ord-013-0006", 10031, "C", OrderSide.Sell, 1000, 1000, bd("61.500"), OrderStatus.NEW),
                seedOrder("ord-013-0007", 62654, "META", OrderSide.Sell, 500, 500, bd("507.880"), OrderStatus.NEW)
            );
            orderRepository.saveAll(seed);
        }
        initializeSequence();
        refreshCountersFromDatabase();
    }

    private OrderRecord seedOrder(
        String orderId,
        int accountId,
        String security,
        OrderSide side,
        int quantity,
        int remaining,
        BigDecimal limitPrice,
        OrderStatus status
    ) {
        Instant now = Instant.now();
        OrderRecord order = new OrderRecord();
        order.setOrderId(orderId);
        order.setAccountId(accountId);
        order.setSecurity(security);
        order.setSide(side);
        order.setQuantity(quantity);
        order.setRemainingQuantity(remaining);
        order.setLimitPrice(limitPrice);
        order.setStatus(status);
        order.setCreatedAt(now);
        order.setUpdatedAt(now);
        return order;
    }

    private BigDecimal bd(String value) {
        return new BigDecimal(value);
    }

    private void initializeSequence() {
        int maxId = orderRepository.findAllOrderIds().stream()
            .map(ORDER_ID_PATTERN::matcher)
            .filter(Matcher::matches)
            .map(m -> Integer.parseInt(m.group(1)))
            .max(Integer::compareTo)
            .orElse(0);
        nextOrderSequence.set(maxId + 1);
    }

    private void initializeCounters() {
        for (String event : List.of("create", "partial_fill", "fill", "cancel", "reject", "force_fill")) {
            eventCounters.put(event, new AtomicLong(0));
        }
    }

    private void refreshCountersFromDatabase() {
        setCounter("create", orderRepository.count());
        setCounter("partial_fill", orderRepository.countByStatus(OrderStatus.PARTIALLY_FILLED));
        setCounter("fill", orderRepository.countByStatus(OrderStatus.FILLED));
        setCounter("cancel", orderRepository.countByStatus(OrderStatus.CANCELED));
        setCounter("reject", orderRepository.countByStatus(OrderStatus.REJECTED));
        setCounter("force_fill", 0);
    }

    private void incrementEvent(String event) {
        eventCounters.computeIfAbsent(event, ignored -> new AtomicLong()).incrementAndGet();
    }

    private long counterValue(String event) {
        return eventCounters.computeIfAbsent(event, ignored -> new AtomicLong()).get();
    }

    private void setCounter(String event, long value) {
        eventCounters.computeIfAbsent(event, ignored -> new AtomicLong()).set(value);
    }

    private String trimTrailingSlash(String url) {
        if (!StringUtils.hasText(url)) {
            return "";
        }
        return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
    }
}
