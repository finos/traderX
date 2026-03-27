#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/trade-service-specfirst"
GRADLE_WRAPPER_TEMPLATE="${ROOT}/templates/gradle-wrapper"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/gradle/wrapper" \
  "${TARGET}/src/main/java/finos/traderx/messaging/socketio" \
  "${TARGET}/src/main/java/finos/traderx/messaging" \
  "${TARGET}/src/main/java/finos/traderx/tradeservice/config" \
  "${TARGET}/src/main/java/finos/traderx/tradeservice/controller" \
  "${TARGET}/src/main/java/finos/traderx/tradeservice/exceptions" \
  "${TARGET}/src/main/java/finos/traderx/tradeservice/model" \
  "${TARGET}/src/main/resources" \
  "${TARGET}/src/main/test/java/finos/traderx/tradeservice"

cat <<'EOF' > "${TARGET}/README.md"
# Trade-Service (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18092` via `TRADING_SERVICE_PORT`
- Reference data endpoint: `REFERENCE_DATA_SERVICE_URL` or `REFERENCE_DATA_HOST`
- Account endpoint: `ACCOUNT_SERVICE_URL` or `ACCOUNT_SERVICE_HOST`
- Trade feed endpoint: `TRADE_FEED_ADDRESS` or `TRADE_FEED_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
EOF

cat <<'EOF' > "${TARGET}/settings.gradle"
rootProject.name = 'trade-service-specfirst'
EOF

cat <<'EOF' > "${TARGET}/build.gradle"
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.3'
  id 'io.spring.dependency-management' version '1.1.7'
}

group = 'finos.traderx.trade-service-specfirst'
version = '0.1.0'

java {
  sourceCompatibility = JavaVersion.VERSION_21
}

repositories {
  mavenCentral()
}

configurations.all {
  exclude group: 'org.yaml', module: 'snakeyaml'
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
server.port=${TRADING_SERVICE_PORT:18092}
spring.threads.virtual.enabled=true

people.service.url=${PEOPLE_SERVICE_URL:http://${PEOPLE_SERVICE_HOST:localhost}:18089}
account.service.url=${ACCOUNT_SERVICE_URL:http://${ACCOUNT_SERVICE_HOST:localhost}:18088}
reference.data.service.url=${REFERENCE_DATA_SERVICE_URL:http://${REFERENCE_DATA_HOST:localhost}:18085}

trade.feed.address=${TRADE_FEED_ADDRESS:http://${TRADE_FEED_HOST:localhost}:18086}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.root=info
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/TradeServiceApplication.java"
package finos.traderx.tradeservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TradeServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(TradeServiceApplication.class, args);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/OpenApiConfig.java"
package finos.traderx.tradeservice;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

  @Value("${server.port}")
  private int port = 18092;

  @Bean
  public OpenAPI config() {
    Info info = new Info()
        .title("FINOS TraderX Trading Service")
        .version("0.1.0")
        .description("Service for capturing trades from the UI, validating, and sending for processing");

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/PubSubConfig.java"
package finos.traderx.tradeservice;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.socketio.SocketIOJSONPublisher;
import finos.traderx.tradeservice.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${trade.feed.address}")
  private String tradeFeedAddress;

  @Bean
  public Publisher<TradeOrder> tradePublisher() {
    SocketIOJSONPublisher<TradeOrder> publisher = new SocketIOJSONPublisher<>() {};
    publisher.setTopic("/trades");
    publisher.setSocketAddress(tradeFeedAddress);
    return publisher;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/config/CorsConfig.java"
package finos.traderx.tradeservice.config;

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/controller/DocsController.java"
package finos.traderx.tradeservice.controller;

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/controller/TradeOrderController.java"
package finos.traderx.tradeservice.controller;

import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import finos.traderx.tradeservice.exceptions.ResourceNotFoundException;
import finos.traderx.tradeservice.model.Account;
import finos.traderx.tradeservice.model.Security;
import finos.traderx.tradeservice.model.TradeOrder;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@RestController
@RequestMapping(value = "/trade", produces = "application/json")
public class TradeOrderController {

  private static final Logger log = LoggerFactory.getLogger(TradeOrderController.class);

  private final Publisher<TradeOrder> tradePublisher;
  private final RestTemplate restTemplate = new RestTemplate();

  @Value("${reference.data.service.url}")
  private String referenceDataServiceAddress;

  @Value("${account.service.url}")
  private String accountServiceAddress;

  public TradeOrderController(Publisher<TradeOrder> tradePublisher) {
    this.tradePublisher = tradePublisher;
  }

  @Operation(description = "Submit a new trade order")
  @PostMapping("/")
  public ResponseEntity<TradeOrder> createTradeOrder(
      @Parameter(description = "the intended trade order") @RequestBody TradeOrder tradeOrder) {
    log.info("Called createTradeOrder");

    if (!validateTicker(tradeOrder.getSecurity())) {
      throw new ResourceNotFoundException(tradeOrder.getSecurity() + " not found in Reference data service.");
    } else if (!validateAccount(tradeOrder.getAccountId())) {
      throw new ResourceNotFoundException(tradeOrder.getAccountId() + " not found in Account service.");
    } else {
      try {
        log.info("Trade is valid. Submitting {}", tradeOrder);
        tradePublisher.publish("/trades", tradeOrder);
        return ResponseEntity.ok(tradeOrder);
      } catch (PubSubException e) {
        throw new RuntimeException("Failed to publish trade order", e);
      }
    }
  }

  private boolean validateTicker(String ticker) {
    String url = this.referenceDataServiceAddress + "/stocks/" + ticker;
    try {
      ResponseEntity<Security> response = this.restTemplate.getForEntity(url, Security.class);
      log.info("Validate ticker {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getRawStatusCode() == 404) {
        log.info("{} not found in reference data service.", ticker);
      } else {
        log.error(ex.getMessage(), ex);
      }
      return false;
    }
  }

  private boolean validateAccount(Integer id) {
    String url = this.accountServiceAddress + "/account/" + id;
    try {
      ResponseEntity<Account> response = this.restTemplate.getForEntity(url, Account.class);
      log.info("Validate account {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getRawStatusCode() == 404) {
        log.info("Account {} not found in account service.", id);
      } else {
        log.error(ex.getMessage(), ex);
      }
      return false;
    }
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/exceptions/ResourceNotFoundException.java"
package finos.traderx.tradeservice.exceptions;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
  public ResourceNotFoundException(String message) {
    super(message);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/model/TradeSide.java"
package finos.traderx.tradeservice.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(name = "The direction of the trade, ie sell or buy order")
public enum TradeSide {
  Buy,
  Sell
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/model/TradeOrder.java"
package finos.traderx.tradeservice.model;

import com.fasterxml.jackson.annotation.JsonAlias;

public class TradeOrder {
  private String id;
  private String state;
  private String security;
  private Integer quantity;

  @JsonAlias("accountID")
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/model/Account.java"
package finos.traderx.tradeservice.model;

public class Account {
  private Integer id;
  private String displayName;

  public Account() {}

  public Account(Integer id, String displayName) {
    this.id = id;
    this.displayName = displayName;
  }

  public Integer getId() {
    return id;
  }

  public void setId(Integer id) {
    this.id = id;
  }

  public String getDisplayName() {
    return displayName;
  }

  public void setDisplayName(String displayName) {
    this.displayName = displayName;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/tradeservice/model/Security.java"
package finos.traderx.tradeservice.model;

public class Security {
  private String ticker;
  private String companyName;

  public Security() {}

  public Security(String ticker, String companyName) {
    this.ticker = ticker;
    this.companyName = companyName;
  }

  public String getTicker() {
    return ticker;
  }

  public void setTicker(String ticker) {
    this.ticker = ticker;
  }

  public String getCompanyName() {
    return companyName;
  }

  public void setCompanyName(String companyName) {
    this.companyName = companyName;
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

cat <<'EOF' > "${TARGET}/src/main/test/java/finos/traderx/tradeservice/TradeServiceApplicationTests.java"
package finos.traderx.tradeservice;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class TradeServiceApplicationTests {

  @Test
  void contextLoads() {
  }
}
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.1
info:
  title: FINOS TraderX Trade Service
  version: 0.1.0
servers:
  - url: ''
paths:
  /trade/:
    post:
      tags:
        - trade-order-controller
      operationId: createTradeOrder
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TradeOrder'
        required: true
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TradeOrder'
        '404':
          description: Unknown account or ticker
components:
  schemas:
    TradeOrder:
      type: object
      properties:
        id:
          type: string
          example: 'ABC-123-XYZ'
        state:
          type: string
          example: 'New'
        security:
          type: string
          example: 'ADBE'
        quantity:
          type: integer
          format: int32
          example: 100
        accountId:
          type: integer
          format: int32
          example: 22214
        accountID:
          type: integer
          format: int32
          example: 22214
        side:
          type: string
          enum:
            - Buy
            - Sell
EOF

cat <<'EOF' > "${TARGET}/Dockerfile"
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18092
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF

cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew" "${TARGET}/gradlew"
cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew.bat" "${TARGET}/gradlew.bat"
cp -R "${GRADLE_WRAPPER_TEMPLATE}/gradle/wrapper/"* "${TARGET}/gradle/wrapper/"
chmod +x "${TARGET}/gradlew"

echo "[done] regenerated ${TARGET}"
