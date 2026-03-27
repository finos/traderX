#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/trade-processor-specfirst"
GRADLE_WRAPPER_TEMPLATE="${ROOT}/templates/gradle-wrapper"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/gradle/wrapper" \
  "${TARGET}/src/main/java/finos/traderx/messaging/socketio" \
  "${TARGET}/src/main/java/finos/traderx/messaging" \
  "${TARGET}/src/main/java/finos/traderx/tradeprocessor/config" \
  "${TARGET}/src/main/java/finos/traderx/tradeprocessor/controller" \
  "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model" \
  "${TARGET}/src/main/java/finos/traderx/tradeprocessor/repository" \
  "${TARGET}/src/main/java/finos/traderx/tradeprocessor/service" \
  "${TARGET}/src/main/resources" \
  "${TARGET}/src/main/test/java/finos/traderx/tradeprocessor"

cat <<'EOF' > "${TARGET}/README.md"
# Trade-Processor (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18091` via `TRADE_PROCESSOR_SERVICE_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- Trade feed: `TRADE_FEED_ADDRESS` or `TRADE_FEED_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
EOF

cat <<'EOF' > "${TARGET}/settings.gradle"
rootProject.name = 'trade-processor-specfirst'
EOF

cat <<'EOF' > "${TARGET}/build.gradle"
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.3'
  id 'io.spring.dependency-management' version '1.1.7'
}

group = 'finos.traderx.trade-processor-specfirst'
version = '0.1.0'

java {
  sourceCompatibility = JavaVersion.VERSION_21
}

repositories {
  mavenCentral()
}

dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
  implementation 'org.springframework.boot:spring-boot-starter-web'
  implementation 'com.h2database:h2:2.3.232'
  implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.6'

  implementation('org.json:json:20240303') {
    because 'previous versions are affected by multiple CVE'
  }
  implementation('io.socket:socket.io-client:2.1.2') {
    exclude group: 'org.json', module: 'json'
  }
  implementation 'com.squareup.okhttp3:okhttp:4.12.0'
  implementation ('ch.qos.logback:logback-core:1.5.18') {
    because 'version brought in by spring boot 3.5.3 affected by CVE-2024-12798'
  }
  implementation 'ch.qos.logback:logback-classic:1.5.18'
  implementation 'org.apache.commons:commons-lang3:3.18.0'

  testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

tasks.withType(Test).configureEach {
  useJUnitPlatform()
}
EOF

cat <<'EOF' > "${TARGET}/src/main/resources/application.properties"
server.port=${TRADE_PROCESSOR_SERVICE_PORT:18091}

spring.datasource.url=jdbc:h2:tcp://${DATABASE_TCP_HOST:localhost}:${DATABASE_TCP_PORT:18082}/${DATABASE_NAME:traderx};CASE_INSENSITIVE_IDENTIFIERS=TRUE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=${DATABASE_DBUSER:sa}
spring.datasource.password=${DATABASE_DBPASS:sa}
spring.data.jpa.database-platform=org.hibernate.dialect.H2Dialect
spring.data.jpa.show-sql=true
spring.jpa.hibernate.ddl-auto=update
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.threads.virtual.enabled=true

trade.feed.address=${TRADE_FEED_ADDRESS:http://${TRADE_FEED_HOST:localhost}:18086}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=DEBUG
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/TradeProcessorApplication.java"
package finos.traderx.tradeprocessor;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TradeProcessorApplication {

  public static void main(String[] args) {
    SpringApplication.run(TradeProcessorApplication.class, args);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/OpenApiConfig.java"
package finos.traderx.tradeprocessor;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

  @Value("${server.port}")
  private int port = 18091;

  @Bean
  public OpenAPI config() {
    Info info = new Info()
        .title("FINOS TraderX Trading Processor")
        .version("0.1.0")
        .description("Service for processing trades from the Trade Feed, persisting trades, updating positions, and publishing updates to the feed");

    OpenAPI api = new OpenAPI()
        .addServersItem(serverInfo("", "Empty URL to help proxied documentation work"))
        .addServersItem(serverInfo("http://localhost:" + port, "Local Dev URL"));

    api.setInfo(info);
    return api;
  }

  private Server serverInfo(String url, String desc) {
    return new Server()
        .description(desc)
        .url(url);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/PubSubConfig.java"
package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.socketio.SocketIOJSONPublisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${trade.feed.address}")
  private String tradeFeedAddress;

  @Bean
  public Publisher<Position> positionPublisher() {
    SocketIOJSONPublisher<Position> publisher = new SocketIOJSONPublisher<>() {};
    publisher.setSocketAddress(tradeFeedAddress);
    return publisher;
  }

  @Bean
  public Publisher<Trade> tradePublisher() {
    SocketIOJSONPublisher<Trade> publisher = new SocketIOJSONPublisher<>() {};
    publisher.setSocketAddress(tradeFeedAddress);
    return publisher;
  }

  @Bean
  public Subscriber<TradeOrder> tradeFeedHandler() {
    TradeFeedHandler handler = new TradeFeedHandler();
    handler.setDefaultTopic("/trades");
    handler.setSocketAddress(tradeFeedAddress);
    return handler;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/TradeFeedHandler.java"
package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.socketio.SocketIOJSONSubscriber;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.springframework.beans.factory.annotation.Autowired;

public class TradeFeedHandler extends SocketIOJSONSubscriber<TradeOrder> {
  static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(TradeFeedHandler.class);

  public TradeFeedHandler() {
    super(TradeOrder.class);
  }

  @Autowired
  private TradeService tradeService;

  @Override
  public void onMessage(Envelope<?> envelope, TradeOrder order) {
    try {
      tradeService.processTrade(order);
    } catch (Exception x) {
      log.error("Error processing trade order {} in envelope {}", order, envelope);
      log.error("Error handling incoming trade order:", x);
    }
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/config/CorsConfig.java"
package finos.traderx.tradeprocessor.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

  @Override
  public void addCorsMappings(CorsRegistry registry) {
    String configured = System.getenv("CORS_ALLOWED_ORIGINS");
    if (configured == null || configured.isBlank() || configured.trim().equals("*")) {
      registry.addMapping("/**")
          .allowedOriginPatterns("*")
          .allowedMethods("*")
          .allowedHeaders("*");
      return;
    }

    String[] origins = configured.split(",");
    for (int i = 0; i < origins.length; i++) {
      origins[i] = origins[i].trim();
    }

    registry.addMapping("/**")
        .allowedOrigins(origins)
        .allowedMethods("*")
        .allowedHeaders("*");
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/controller/DocsController.java"
package finos.traderx.tradeprocessor.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
public class DocsController {

  @RequestMapping("/")
  public String index() {
    return "redirect:swagger-ui.html";
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/controller/TradeServiceController.java"
package finos.traderx.tradeprocessor.controller;

import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/tradeservice")
public class TradeServiceController {

  private final TradeService tradeService;

  public TradeServiceController(TradeService tradeService) {
    this.tradeService = tradeService;
  }

  @PostMapping("/order")
  public ResponseEntity<TradeBookingResult> processOrder(@RequestBody TradeOrder order) {
    TradeBookingResult result = tradeService.processTrade(order);
    return ResponseEntity.ok(result);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/TradeSide.java"
package finos.traderx.tradeprocessor.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "The direction of the trade, ie sell or buy order")
public enum TradeSide {
  Buy,
  Sell
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/TradeState.java"
package finos.traderx.tradeprocessor.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "The state of the trade, ie, New, Processing, Settled, Cancelled")
public enum TradeState {
  New,
  Processing,
  Settled,
  Cancelled
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/TradeOrder.java"
package finos.traderx.tradeprocessor.model;

public class TradeOrder {

  private String id;
  private String state;
  private String security;
  private Integer quantity;
  private Integer accountId;
  private TradeSide side;

  public TradeOrder() {}

  public TradeOrder(String id, int accountId, String security, TradeSide side, int quantity) {
    this.accountId = accountId;
    this.security = security;
    this.side = side;
    this.quantity = quantity;
    this.id = id;
  }

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getState() {
    return state;
  }

  public void setState(String state) {
    this.state = state;
  }

  public Integer getAccountId() {
    return accountId;
  }

  public void setAccountId(Integer accountId) {
    this.accountId = accountId;
  }

  public String getSecurity() {
    return security;
  }

  public void setSecurity(String security) {
    this.security = security;
  }

  public Integer getQuantity() {
    return quantity;
  }

  public void setQuantity(Integer quantity) {
    this.quantity = quantity;
  }

  public TradeSide getSide() {
    return side;
  }

  public void setSide(TradeSide side) {
    this.side = side;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/Trade.java"
package finos.traderx.tradeprocessor.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.io.Serial;
import java.io.Serializable;
import java.util.Date;

@Entity
@Table(name = "TRADES")
public class Trade implements Serializable {

  @Serial
  private static final long serialVersionUID = 1L;

  @Id
  @Column(length = 100, name = "ID")
  private String id;

  @Column(name = "ACCOUNTID")
  private Integer accountId;

  @Column(length = 50, name = "SECURITY")
  private String security;

  @Enumerated(EnumType.STRING)
  @Column(length = 4, name = "SIDE")
  private TradeSide side;

  @Enumerated(EnumType.STRING)
  @Column(length = 20, name = "STATE")
  private TradeState state = TradeState.New;

  @Column(name = "QUANTITY")
  private Integer quantity;

  @Column(name = "UPDATED")
  private Date updated;

  @Column(name = "CREATED")
  private Date created;

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public Integer getAccountId() {
    return accountId;
  }

  public void setAccountId(Integer accountId) {
    this.accountId = accountId;
  }

  public String getSecurity() {
    return security;
  }

  public void setSecurity(String security) {
    this.security = security;
  }

  public TradeSide getSide() {
    return side;
  }

  public void setSide(TradeSide side) {
    this.side = side;
  }

  public TradeState getState() {
    return state;
  }

  public void setState(TradeState state) {
    this.state = state;
  }

  public Integer getQuantity() {
    return quantity;
  }

  public void setQuantity(Integer quantity) {
    this.quantity = quantity;
  }

  public Date getUpdated() {
    return updated;
  }

  public void setUpdated(Date updated) {
    this.updated = updated;
  }

  public Date getCreated() {
    return created;
  }

  public void setCreated(Date created) {
    this.created = created;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/PositionID.java"
package finos.traderx.tradeprocessor.model;

import java.io.Serializable;
import java.util.Objects;

public class PositionID implements Serializable {
  private Integer accountId;
  private String security;

  public PositionID() {
    // JPA
  }

  public PositionID(Integer accountId, String security) {
    this.accountId = accountId;
    this.security = security;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    PositionID that = (PositionID) o;
    return Objects.equals(accountId, that.accountId) && Objects.equals(security, that.security);
  }

  @Override
  public int hashCode() {
    return Objects.hash(accountId, security);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/Position.java"
package finos.traderx.tradeprocessor.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serial;
import java.io.Serializable;
import java.util.Date;

@Entity
@IdClass(PositionID.class)
@Table(name = "POSITIONS")
public class Position implements Serializable {

  @Serial
  private static final long serialVersionUID = 1L;

  @Id
  @Column(name = "ACCOUNTID")
  private Integer accountId;

  @Id
  @Column(length = 50, name = "SECURITY")
  private String security;

  @Column(name = "QUANTITY")
  private Integer quantity;

  @Column(name = "UPDATED")
  private Date updated;

  public Integer getAccountId() {
    return accountId;
  }

  public void setAccountId(Integer accountId) {
    this.accountId = accountId;
  }

  public String getSecurity() {
    return security;
  }

  public void setSecurity(String security) {
    this.security = security;
  }

  public Integer getQuantity() {
    return quantity;
  }

  public void setQuantity(Integer quantity) {
    this.quantity = quantity;
  }

  public Date getUpdated() {
    return updated;
  }

  public void setUpdated(Date updated) {
    this.updated = updated;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/model/TradeBookingResult.java"
package finos.traderx.tradeprocessor.model;

public class TradeBookingResult {
  private Trade trade;
  private Position position;

  public TradeBookingResult() {}

  public TradeBookingResult(Trade trade, Position position) {
    this.trade = trade;
    this.position = position;
  }

  public Trade getTrade() {
    return trade;
  }

  public void setTrade(Trade trade) {
    this.trade = trade;
  }

  public Position getPosition() {
    return position;
  }

  public void setPosition(Position position) {
    this.position = position;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/repository/TradeRepository.java"
package finos.traderx.tradeprocessor.repository;

import finos.traderx.tradeprocessor.model.Trade;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TradeRepository extends JpaRepository<Trade, String> {
  List<Trade> findByAccountId(Integer id);
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/repository/PositionRepository.java"
package finos.traderx.tradeprocessor.repository;

import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.PositionID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PositionRepository extends JpaRepository<Position, PositionID> {
  List<Position> findByAccountId(Integer id);
  Position findByAccountIdAndSecurity(Integer id, String security);
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeprocessor/service/TradeService.java"
package finos.traderx.tradeprocessor.service;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeBookingResult;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.model.TradeSide;
import finos.traderx.tradeprocessor.model.TradeState;
import finos.traderx.tradeprocessor.repository.PositionRepository;
import finos.traderx.tradeprocessor.repository.TradeRepository;
import java.util.Date;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TradeService {
  private static final Logger log = LoggerFactory.getLogger(TradeService.class);

  private final TradeRepository tradeRepository;
  private final PositionRepository positionRepository;
  private final Publisher<Trade> tradePublisher;
  private final Publisher<Position> positionPublisher;

  public TradeService(
      TradeRepository tradeRepository,
      PositionRepository positionRepository,
      Publisher<Trade> tradePublisher,
      Publisher<Position> positionPublisher) {
    this.tradeRepository = tradeRepository;
    this.positionRepository = positionRepository;
    this.tradePublisher = tradePublisher;
    this.positionPublisher = positionPublisher;
  }

  @Transactional
  public TradeBookingResult processTrade(TradeOrder order) {
    log.info("Trade order received: {}", order);

    Trade trade = new Trade();
    trade.setId(UUID.randomUUID().toString());
    trade.setAccountId(order.getAccountId());
    trade.setSecurity(order.getSecurity());
    trade.setSide(order.getSide());
    trade.setQuantity(order.getQuantity());
    trade.setCreated(new Date());
    trade.setUpdated(new Date());
    trade.setState(TradeState.New);

    Position position = positionRepository.findByAccountIdAndSecurity(order.getAccountId(), order.getSecurity());
    if (position == null) {
      position = new Position();
      position.setAccountId(order.getAccountId());
      position.setSecurity(order.getSecurity());
      position.setQuantity(0);
    }

    int signedQuantity = ((order.getSide() == TradeSide.Buy) ? 1 : -1) * trade.getQuantity();
    position.setQuantity(position.getQuantity() + signedQuantity);
    position.setUpdated(new Date());

    tradeRepository.save(trade);
    positionRepository.save(position);

    trade.setUpdated(new Date());
    trade.setState(TradeState.Processing);
    trade.setUpdated(new Date());
    trade.setState(TradeState.Settled);
    tradeRepository.save(trade);

    TradeBookingResult result = new TradeBookingResult(trade, position);
    log.info("Trade Processing complete: {}", result);

    try {
      tradePublisher.publish("/accounts/" + order.getAccountId() + "/trades", result.getTrade());
      positionPublisher.publish("/accounts/" + order.getAccountId() + "/positions", result.getPosition());
    } catch (PubSubException exc) {
      log.error("Error publishing trade {}", order, exc);
    }

    return result;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/Envelope.java"
package finos.traderx.messaging;

import java.util.Date;

public interface Envelope<T> {
  String getType();
  String getTopic();
  T getPayload();
  Date getDate();
  String getFrom();
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/Publisher.java"
package finos.traderx.messaging;

public interface Publisher<T> {
  void publish(T message) throws PubSubException;
  void publish(String topic, T message) throws PubSubException;
  boolean isConnected();
  void connect() throws PubSubException;
  void disconnect() throws PubSubException;
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/Subscriber.java"
package finos.traderx.messaging;

public interface Subscriber<T> {
  void subscribe(String topic) throws PubSubException;
  void unsubscribe(String topic) throws PubSubException;
  void onMessage(Envelope<?> envelope, T message);
  boolean isConnected();
  void connect() throws PubSubException;
  void disconnect() throws PubSubException;
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/PubSubException.java"
package finos.traderx.messaging;

public class PubSubException extends Exception {

  public PubSubException(String message) {
    super(message);
  }

  public PubSubException(String message, Throwable throwable) {
    super(message, throwable);
  }

  public PubSubException(Throwable throwable) {
    super(throwable);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/socketio/SocketIOEnvelope.java"
package finos.traderx.messaging.socketio;

import finos.traderx.messaging.Envelope;
import java.util.Date;

public class SocketIOEnvelope<T> implements Envelope<T> {
  private String topic;
  private T payload;
  private Date date = new Date();
  private String from;
  private String type;

  public SocketIOEnvelope() {}

  public SocketIOEnvelope(String topic, T payload) {
    this.payload = payload;
    this.topic = topic;
    this.type = payload.getClass().getSimpleName();
  }

  public void setType(String type) {
    this.type = type;
  }

  public void setPayload(T payload) {
    this.payload = payload;
  }

  public void setTopic(String topic) {
    this.topic = topic;
  }

  public void setFrom(String from) {
    this.from = from;
  }

  @Override
  public String getType() {
    return type;
  }

  @Override
  public String getTopic() {
    return topic;
  }

  @Override
  public T getPayload() {
    return payload;
  }

  @Override
  public Date getDate() {
    return date;
  }

  @Override
  public String getFrom() {
    return from;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/socketio/SocketIOJSONPublisher.java"
package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.socket.client.IO;
import io.socket.client.Socket;
import io.socket.emitter.Emitter;
import java.net.URI;
import org.json.JSONObject;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public abstract class SocketIOJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  protected IO.Options getIOOptions() {
    return new IO.Options();
  }

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  boolean connected = false;
  Socket socket;
  String socketAddress = "http://localhost:3000";
  String topic = "/default";

  public void setSocketAddress(String addr) {
    socketAddress = addr;
  }

  public void setTopic(String topic) {
    this.topic = topic;
  }

  @Override
  public boolean isConnected() {
    return connected;
  }

  @Override
  public void publish(T message) throws PubSubException {
    publish(topic, message);
  }

  @Override
  public void publish(String topic, T message) throws PubSubException {
    if (!isConnected()) {
      throw new PubSubException("Cannot send %s on topic %s - not connected".formatted(message, topic));
    }
    try {
      SocketIOEnvelope<T> envelope = new SocketIOEnvelope<>(topic, message);
      String msgString = OBJECT_MAPPER.writerFor(SocketIOEnvelope.class).writeValueAsString(envelope);
      JSONObject obj = new JSONObject(msgString);
      log.debug("PUBLISH->{}", obj);
      socket.emit("publish", obj);
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    if (socket != null && isConnected()) {
      socket.disconnect();
    }
    socket = null;
  }

  @Override
  public void connect() throws PubSubException {
    if (socket != null) {
      socket.disconnect();
    }
    try {
      socket = internalConnect(URI.create(socketAddress));
    } catch (Exception x) {
      throw new PubSubException("Cannot socket connection at " + socketAddress, x);
    }
  }

  protected Socket internalConnect(URI uri) throws Exception {
    return IO.socket(uri, getIOOptions());
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
    socket.on(Socket.EVENT_CONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = true;
        log.info("Socket Connected {}", args);
      }
    });

    socket.on(Socket.EVENT_DISCONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = false;
        log.info("Socket Disconnected {}", args);
      }
    });

    socket.on(Socket.EVENT_CONNECT_ERROR, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONPublisher.this.connected = false;
        log.info("Connection Error {}", args);
      }
    });
    socket.connect();
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/messaging/socketio/SocketIOJSONSubscriber.java"
package finos.traderx.messaging.socketio;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Subscriber;
import io.socket.client.IO;
import io.socket.client.Socket;
import io.socket.emitter.Emitter;
import java.net.URI;
import org.json.JSONObject;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public abstract class SocketIOJSONSubscriber<T> implements Subscriber<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  public SocketIOJSONSubscriber(Class<T> typeClass) {
    JavaType type = OBJECT_MAPPER.getTypeFactory().constructParametricType(SocketIOEnvelope.class, typeClass);
    this.envelopeType = type;
    this.objectType = typeClass;
  }

  protected IO.Options getIOOptions() {
    return new IO.Options();
  }

  final JavaType envelopeType;
  final Class<T> objectType;

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  boolean connected = false;
  Socket socket;
  String socketAddress = "http://localhost:3000";
  private String defaultTopic = "/default";

  public void setSocketAddress(String addr) {
    socketAddress = addr;
  }

  public void setDefaultTopic(String topic) {
    defaultTopic = topic;
  }

  @Override
  public boolean isConnected() {
    return connected;
  }

  @Override
  public void subscribe(String topic) throws PubSubException {
    log.info("Subscribing to {}", topic);
    socket.emit("subscribe", topic);
  }

  @Override
  public void unsubscribe(String topic) throws PubSubException {
    socket.emit("unsubscribe", topic);
  }

  @Override
  public void disconnect() throws PubSubException {
    if (socket != null && isConnected()) {
      socket.disconnect();
    }
    socket = null;
  }

  @Override
  public void connect() throws PubSubException {
    if (socket != null) {
      socket.disconnect();
    }
    try {
      socket = internalConnect(URI.create(socketAddress));
    } catch (Exception x) {
      throw new PubSubException("Cannot socket connection at " + socketAddress, x);
    }
  }

  protected Socket internalConnect(URI uri) throws Exception {
    Socket s = IO.socket(uri, getIOOptions());
    s.on(Socket.EVENT_CONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONSubscriber.this.connected = true;
        log.info("Socket Connected");
      }
    });

    s.on(Socket.EVENT_DISCONNECT, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONSubscriber.this.connected = false;
        log.info("Socket Disconnected");
      }
    });

    s.on(Socket.EVENT_CONNECT_ERROR, new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        SocketIOJSONSubscriber.this.connected = false;
        log.info("Connection Error");
      }
    });

    s.on("publish", new Emitter.Listener() {
      @Override
      public void call(Object... args) {
        try {
          JSONObject json = (JSONObject) args[0];
          if (!objectType.getSimpleName().equals(json.get("type"))) {
            log.debug("Ignoring non-target message type {}", json.get("type"));
          } else {
            SocketIOEnvelope<T> envelope = (SocketIOEnvelope<T>) OBJECT_MAPPER.readValue(json.toString(), envelopeType);
            SocketIOJSONSubscriber.this.onMessage(envelope, envelope.getPayload());
          }
        } catch (Exception x) {
          log.error("Threw exception while handling incoming message", x);
        }
      }
    });
    s.connect();
    return s;
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
    subscribe(defaultTopic);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/test/java/finos/traderx/tradeprocessor/TradeProcessorApplicationTests.java"
package finos.traderx.tradeprocessor;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class TradeProcessorApplicationTests {

  @Test
  void contextLoads() {
  }
}
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.1
info:
  title: "Trade Processor - TraderX"
  version: "1.0"
paths:
  /tradeservice/order:
    post:
      operationId: processOrder
      responses:
        '200':
          description: Trade booking result
  /:
    get:
      operationId: docsRoot
      responses:
        '302':
          description: Redirect to swagger-ui
components:
  schemas:
    TradeOrder:
      type: object
      properties:
        id:
          type: string
        accountId:
          type: integer
          format: int32
        security:
          type: string
        side:
          type: string
        quantity:
          type: integer
          format: int32
    Position:
      type: object
      properties:
        accountId:
          type: integer
          format: int32
        security:
          type: string
        quantity:
          type: integer
          format: int32
    Trade:
      type: object
      properties:
        id:
          type: string
        accountId:
          type: integer
          format: int32
        security:
          type: string
        side:
          type: string
        state:
          type: string
        quantity:
          type: integer
          format: int32
    TradeBookingResult:
      type: object
      properties:
        trade:
          $ref: '#/components/schemas/Trade'
        position:
          $ref: '#/components/schemas/Position'
EOF

cat <<'EOF' > "${TARGET}/Dockerfile"
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18091
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF

cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew" "${TARGET}/gradlew"
cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew.bat" "${TARGET}/gradlew.bat"
cp -R "${GRADLE_WRAPPER_TEMPLATE}/gradle/wrapper/"* "${TARGET}/gradle/wrapper/"
chmod +x "${TARGET}/gradlew"

echo "[done] regenerated ${TARGET}"
