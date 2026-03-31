#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="007-messaging-nats-replacement"
TARGET="${ROOT}/generated/code/target-generated"
STATE_DIR="${TARGET}/messaging-nats-replacement"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"

echo "[info] generating parent state 003 for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" 003-containerized-compose-runtime

[[ -d "${TARGET}" ]] || {
  echo "[fail] missing target output: ${TARGET}"
  exit 1
}

write_trade_service_overlay() {
  local svc="${TARGET}/trade-service"

  cat > "${svc}/build.gradle" <<'EOF'
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
  implementation 'io.nats:jnats:2.20.5'

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

  cat > "${svc}/src/main/java/finos/traderx/tradeservice/PubSubConfig.java" <<'EOF'
package finos.traderx.tradeservice;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.tradeservice.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${nats.address}")
  private String natsAddress;

  @Bean
  public Publisher<TradeOrder> tradePublisher() {
    NatsJSONPublisher<TradeOrder> publisher = new NatsJSONPublisher<>();
    publisher.setTopic("/trades");
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-service");
    return publisher;
  }
}
EOF

  mkdir -p "${svc}/src/main/java/finos/traderx/messaging/nats"
  cat > "${svc}/src/main/java/finos/traderx/messaging/nats/NatsEnvelope.java" <<'EOF'
package finos.traderx.messaging.nats;

import finos.traderx.messaging.Envelope;
import java.util.Date;

public class NatsEnvelope<T> implements Envelope<T> {
  private String topic;
  private T payload;
  private Date date = new Date();
  private String from;
  private String type;

  public NatsEnvelope() {}

  public NatsEnvelope(String topic, T payload, String from) {
    this.payload = payload;
    this.topic = topic;
    this.from = from;
    this.type = (payload == null) ? "Unknown" : payload.getClass().getSimpleName();
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

  cat > "${svc}/src/main/java/finos/traderx/messaging/nats/NatsJSONPublisher.java" <<'EOF'
package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public class NatsJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private String serverAddress = "nats://localhost:4222";
  private String topic = "/default";
  private String sender = "publisher";

  public void setServerAddress(String addr) {
    serverAddress = addr;
  }

  public void setTopic(String value) {
    topic = value;
  }

  public void setSender(String value) {
    sender = value;
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
      NatsEnvelope<T> envelope = new NatsEnvelope<>(topic, message, sender);
      byte[] payload = OBJECT_MAPPER.writeValueAsBytes(envelope);
      connection.publish(topic, payload);
      connection.flush(Duration.ofSeconds(2));
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    try {
      if (connection != null) {
        connection.close();
      }
      connected = false;
      connection = null;
    } catch (Exception x) {
      throw new PubSubException("Failed to close NATS connection", x);
    }
  }

  @Override
  public void connect() throws PubSubException {
    try {
      Options options = new Options.Builder()
          .server(serverAddress)
          .maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5))
          .build();
      connection = Nats.connect(options);
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
  }
}
EOF

  cat > "${svc}/src/main/resources/application.properties" <<'EOF'
server.port=${TRADING_SERVICE_PORT:18092}
spring.threads.virtual.enabled=true

people.service.url=${PEOPLE_SERVICE_URL:http://${PEOPLE_SERVICE_HOST:localhost}:18089}
account.service.url=${ACCOUNT_SERVICE_URL:http://${ACCOUNT_SERVICE_HOST:localhost}:18088}
reference.data.service.url=${REFERENCE_DATA_SERVICE_URL:http://${REFERENCE_DATA_HOST:localhost}:18085}

nats.address=${NATS_ADDRESS:nats://${NATS_BROKER_HOST:localhost}:4222}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.root=info
EOF
}

write_trade_processor_overlay() {
  local svc="${TARGET}/trade-processor"

  cat > "${svc}/build.gradle" <<'EOF'
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
  implementation 'io.nats:jnats:2.20.5'

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

  cat > "${svc}/src/main/java/finos/traderx/tradeprocessor/PubSubConfig.java" <<'EOF'
package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Publisher;
import finos.traderx.messaging.Subscriber;
import finos.traderx.messaging.nats.NatsJSONPublisher;
import finos.traderx.tradeprocessor.model.Position;
import finos.traderx.tradeprocessor.model.Trade;
import finos.traderx.tradeprocessor.model.TradeOrder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PubSubConfig {
  @Value("${nats.address}")
  private String natsAddress;

  @Bean
  public Publisher<Position> positionPublisher() {
    NatsJSONPublisher<Position> publisher = new NatsJSONPublisher<>();
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-processor");
    return publisher;
  }

  @Bean
  public Publisher<Trade> tradePublisher() {
    NatsJSONPublisher<Trade> publisher = new NatsJSONPublisher<>();
    publisher.setServerAddress(natsAddress);
    publisher.setSender("trade-processor");
    return publisher;
  }

  @Bean
  public Subscriber<TradeOrder> tradeFeedHandler() {
    TradeFeedHandler handler = new TradeFeedHandler();
    handler.setDefaultTopic("/trades");
    handler.setServerAddress(natsAddress);
    return handler;
  }
}
EOF

  cat > "${svc}/src/main/java/finos/traderx/tradeprocessor/TradeFeedHandler.java" <<'EOF'
package finos.traderx.tradeprocessor;

import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.nats.NatsJSONSubscriber;
import finos.traderx.tradeprocessor.model.TradeOrder;
import finos.traderx.tradeprocessor.service.TradeService;
import org.springframework.beans.factory.annotation.Autowired;

public class TradeFeedHandler extends NatsJSONSubscriber<TradeOrder> {
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

  mkdir -p "${svc}/src/main/java/finos/traderx/messaging/nats"
  cat > "${svc}/src/main/java/finos/traderx/messaging/nats/NatsEnvelope.java" <<'EOF'
package finos.traderx.messaging.nats;

import finos.traderx.messaging.Envelope;
import java.util.Date;

public class NatsEnvelope<T> implements Envelope<T> {
  private String topic;
  private T payload;
  private Date date = new Date();
  private String from;
  private String type;

  public NatsEnvelope() {}

  public NatsEnvelope(String topic, T payload, String from) {
    this.payload = payload;
    this.topic = topic;
    this.from = from;
    this.type = (payload == null) ? "Unknown" : payload.getClass().getSimpleName();
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

  cat > "${svc}/src/main/java/finos/traderx/messaging/nats/NatsJSONPublisher.java" <<'EOF'
package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Publisher;
import io.nats.client.Connection;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public class NatsJSONPublisher<T> implements Publisher<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private String serverAddress = "nats://localhost:4222";
  private String topic = "/default";
  private String sender = "publisher";

  public void setServerAddress(String addr) {
    serverAddress = addr;
  }

  public void setTopic(String value) {
    topic = value;
  }

  public void setSender(String value) {
    sender = value;
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
      NatsEnvelope<T> envelope = new NatsEnvelope<>(topic, message, sender);
      byte[] payload = OBJECT_MAPPER.writeValueAsBytes(envelope);
      connection.publish(topic, payload);
      connection.flush(Duration.ofSeconds(2));
    } catch (Exception x) {
      throw new PubSubException("Unable to publish on topic " + topic, x);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    try {
      if (connection != null) {
        connection.close();
      }
      connected = false;
      connection = null;
    } catch (Exception x) {
      throw new PubSubException("Failed to close NATS connection", x);
    }
  }

  @Override
  public void connect() throws PubSubException {
    try {
      Options options = new Options.Builder()
          .server(serverAddress)
          .maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5))
          .build();
      connection = Nats.connect(options);
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
  }
}
EOF

  cat > "${svc}/src/main/java/finos/traderx/messaging/nats/NatsJSONSubscriber.java" <<'EOF'
package finos.traderx.messaging.nats;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import finos.traderx.messaging.Envelope;
import finos.traderx.messaging.PubSubException;
import finos.traderx.messaging.Subscriber;
import io.nats.client.Connection;
import io.nats.client.Dispatcher;
import io.nats.client.Nats;
import io.nats.client.Options;
import java.time.Duration;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;

public abstract class NatsJSONSubscriber<T> implements Subscriber<T>, InitializingBean {
  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper()
      .setSerializationInclusion(JsonInclude.Include.NON_NULL);

  final JavaType envelopeType;
  final Class<T> objectType;

  org.slf4j.Logger log = LoggerFactory.getLogger(this.getClass().getName());

  private boolean connected = false;
  private Connection connection;
  private Dispatcher dispatcher;
  private String serverAddress = "nats://localhost:4222";
  private String defaultTopic = "/default";

  public NatsJSONSubscriber(Class<T> typeClass) {
    JavaType type = OBJECT_MAPPER.getTypeFactory().constructParametricType(NatsEnvelope.class, typeClass);
    this.envelopeType = type;
    this.objectType = typeClass;
  }

  public void setServerAddress(String addr) {
    serverAddress = addr;
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
    if (!isConnected() || dispatcher == null) {
      throw new PubSubException("Cannot subscribe - NATS connection is not ready");
    }
    dispatcher.subscribe(topic);
    log.info("Subscribed to {}", topic);
  }

  @Override
  public void unsubscribe(String topic) throws PubSubException {
    if (dispatcher != null) {
      dispatcher.unsubscribe(topic);
    }
  }

  @Override
  public void disconnect() throws PubSubException {
    try {
      if (connection != null) {
        connection.close();
      }
      connected = false;
      connection = null;
      dispatcher = null;
    } catch (Exception x) {
      throw new PubSubException("Failed to close NATS connection", x);
    }
  }

  @Override
  public void connect() throws PubSubException {
    try {
      Options options = new Options.Builder()
          .server(serverAddress)
          .maxReconnects(-1)
          .connectionTimeout(Duration.ofSeconds(5))
          .build();
      connection = Nats.connect(options);
      dispatcher = connection.createDispatcher(msg -> {
        try {
          NatsEnvelope<T> envelope = OBJECT_MAPPER.readValue(msg.getData(), envelopeType);
          if (envelope.getPayload() == null) {
            log.debug("Ignoring message with empty payload on {}", msg.getSubject());
            return;
          }
          if (!objectType.getSimpleName().equals(envelope.getType())) {
            log.debug("Ignoring non-target message type {}", envelope.getType());
            return;
          }
          onMessage(envelope, envelope.getPayload());
        } catch (Exception x) {
          log.error("Threw exception while handling incoming message", x);
        }
      });
      connected = true;
      log.info("Connected to NATS at {}", serverAddress);
    } catch (Exception x) {
      throw new PubSubException("Cannot connect to NATS at " + serverAddress, x);
    }
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    connect();
    subscribe(defaultTopic);
  }
}
EOF

  cat > "${svc}/src/main/resources/application.properties" <<'EOF'
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

nats.address=${NATS_ADDRESS:nats://${NATS_BROKER_HOST:localhost}:4222}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=DEBUG
EOF
}

write_web_overlay() {
  local web="${TARGET}/web-front-end/angular"

  cat > "${web}/main/app/service/trade-feed.service.ts" <<'EOF'
import { Injectable } from '@angular/core';
import { environment } from 'main/environments/environment';

type SubscriptionRecord = {
    sid: number;
    topic: string;
    callback: (...args: any[]) => void;
};

type PendingMsg = {
    subject: string;
    sid: number;
    bytes: number;
};

@Injectable({
    providedIn: 'root'
})
export class TradeFeedService {
    private socket: WebSocket | null = null;
    private reconnectTimer: number | null = null;
    private connected = false;
    private nextSid = 1;
    private pendingData = '';
    private pendingMsg: PendingMsg | null = null;
    private readonly subscriptions = new Map<number, SubscriptionRecord>();

    constructor() {
        this.connect();
    }

    private connect() {
        if (this.socket && (this.socket.readyState === WebSocket.OPEN || this.socket.readyState === WebSocket.CONNECTING)) {
            return;
        }
        const ws = new WebSocket(environment.tradeFeedUrl);
        this.socket = ws;

        ws.onopen = () => {
            this.connected = true;
            this.pendingData = '';
            this.pendingMsg = null;
            this.sendRaw('CONNECT {"protocol":1,"verbose":false,"pedantic":false,"echo":false}\r\n');
            this.sendRaw('PING\r\n');
            this.resubscribeAll();
            console.log(`Trade feed (NATS websocket) connected: ${environment.tradeFeedUrl}`);
        };

        ws.onmessage = (event) => {
            void this.handleIncoming(event.data);
        };

        ws.onerror = (event) => {
            console.error('NATS websocket error', event);
        };

        ws.onclose = () => {
            this.connected = false;
            this.pendingData = '';
            this.pendingMsg = null;
            this.scheduleReconnect();
            console.warn('NATS websocket disconnected; reconnect scheduled');
        };
    }

    private scheduleReconnect() {
        if (this.reconnectTimer !== null) {
            window.clearTimeout(this.reconnectTimer);
        }
        this.reconnectTimer = window.setTimeout(() => {
            this.reconnectTimer = null;
            this.connect();
        }, 1000);
    }

    private sendRaw(payload: string) {
        if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
            return;
        }
        this.socket.send(payload);
    }

    private resubscribeAll() {
        for (const subscription of this.subscriptions.values()) {
            this.sendRaw(`SUB ${subscription.topic} ${subscription.sid}\r\n`);
        }
        if (this.subscriptions.size > 0) {
            this.sendRaw('PING\r\n');
        }
    }

    private async handleIncoming(rawData: unknown) {
        if (typeof rawData === 'string') {
            this.consumeText(rawData);
            return;
        }
        if (rawData instanceof Blob) {
            const text = await rawData.text();
            this.consumeText(text);
            return;
        }
        if (rawData instanceof ArrayBuffer) {
            const text = new TextDecoder().decode(new Uint8Array(rawData));
            this.consumeText(text);
        }
    }

    private consumeText(chunk: string) {
        this.pendingData += chunk;

        while (true) {
            if (this.pendingMsg) {
                const total = this.pendingMsg.bytes + 2;
                if (this.pendingData.length < total) {
                    return;
                }

                const payload = this.pendingData.slice(0, this.pendingMsg.bytes);
                this.pendingData = this.pendingData.slice(total);
                this.dispatchMessage(this.pendingMsg.sid, payload);
                this.pendingMsg = null;
                continue;
            }

            const lineEnd = this.pendingData.indexOf('\r\n');
            if (lineEnd < 0) {
                return;
            }

            const line = this.pendingData.slice(0, lineEnd);
            this.pendingData = this.pendingData.slice(lineEnd + 2);
            if (!line) {
                continue;
            }

            if (line.startsWith('PING')) {
                this.sendRaw('PONG\r\n');
                continue;
            }

            if (line.startsWith('INFO') || line.startsWith('PONG')) {
                continue;
            }

            if (line.startsWith('MSG ')) {
                const parts = line.split(' ');
                if (parts.length < 4) {
                    continue;
                }
                const subject = parts[1];
                const sid = Number(parts[2]);
                const bytes = Number(parts[parts.length - 1]);
                if (!Number.isFinite(sid) || !Number.isFinite(bytes)) {
                    continue;
                }
                this.pendingMsg = { subject, sid, bytes };
            }
        }
    }

    private dispatchMessage(sid: number, payloadText: string) {
        const record = this.subscriptions.get(sid);
        if (!record) {
            return;
        }
        try {
            const parsed = JSON.parse(payloadText);
            if (parsed && typeof parsed === 'object' && 'payload' in parsed) {
                record.callback((parsed as any).payload);
            } else {
                record.callback(parsed);
            }
        } catch (err) {
            console.error('Failed to parse NATS websocket payload', err);
        }
    }

    private removeSubscription(sid: number) {
        this.subscriptions.delete(sid);
        this.sendRaw(`UNSUB ${sid}\r\n`);
    }

    public subscribe(topic: string, callback: (...args: any[]) => void) {
        const sid = this.nextSid++;
        this.subscriptions.set(sid, { sid, topic, callback });
        this.connect();
        this.sendRaw(`SUB ${topic} ${sid}\r\n`);
        this.sendRaw('PING\r\n');
        console.log(`Subscribed to NATS topic ${topic} (sid=${sid})`);

        return () => {
            this.removeSubscription(sid);
        };
    }

    public unSubscribe(topic: string, callback: (...args: any[]) => void) {
        for (const [sid, record] of this.subscriptions.entries()) {
            if (record.topic === topic && record.callback === callback) {
                this.removeSubscription(sid);
            }
        }
    }
}
EOF

  cat > "${web}/main/environments/environment.ts" <<'EOF'
export const environment = {
    production:         false,
    accountUrl:         `//${window.location.hostname}:18088`,
    refrenceDataUrl:    `//${window.location.hostname}:18085`,
    tradesUrl:          `//${window.location.hostname}:18092/trade/`,
    positionsUrl:       `//${window.location.hostname}:18090`,
    peopleUrl:          `//${window.location.hostname}:18089`,
    tradeFeedUrl:       `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/nats-ws`
};
EOF

  cat > "${web}/main/environments/environment.local.ts" <<'EOF'
export const environment = {
    production:         false,
    accountUrl:         `//${window.location.hostname}:18088`,
    refrenceDataUrl:    `//${window.location.hostname}:18085`,
    tradesUrl:          `//${window.location.hostname}:18092/trade/`,
    positionsUrl:       `//${window.location.hostname}:18090`,
    peopleUrl:          `//${window.location.hostname}:18089`,
    tradeFeedUrl:       `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/nats-ws`
};
EOF

  cat > "${web}/main/environments/environment.prod.ts" <<'EOF'
export const environment = {
    production:         true,
    accountUrl:         `//${window.location.host}/account-service`,
    refrenceDataUrl:    `//${window.location.host}/reference-data`,
    tradesUrl:          `//${window.location.host}/trade-service/trade/`,
    positionsUrl:       `//${window.location.host}/position-service`,
    peopleUrl:          `//${window.location.host}/people-service`,
    tradeFeedUrl:       `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/nats-ws`
};
EOF
}

write_ingress_overlay() {
  local ingress="${TARGET}/ingress"
  cat > "${ingress}/nginx.traderx.conf.template" <<'EOF'
server {
    listen 8080;
    server_name ${NGINX_HOST};

    location = /health {
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    location /db-web/ {
        proxy_pass ${DATABASE_URL};
    }

    location /reference-data/ {
        proxy_pass ${REFERENCE_DATA_URL};
    }

    location /ng-cli-ws {
        proxy_pass ${WEB_FRONTEND_URL}/ng-cli-ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /nats-ws {
        proxy_pass http://nats-broker:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
    }

    location /people-service/ {
        proxy_pass ${PEOPLE_SERVICE_URL};
    }

    location /account-service/ {
        proxy_pass ${ACCOUNT_SERVICE_URL};
    }

    location /position-service/ {
        proxy_pass ${POSITION_SERVICE_URL};
    }

    location /trade-service/ {
        proxy_pass ${TRADE_SERVICE_URL};
    }

    location /trade-processor/ {
        proxy_pass ${TRADE_PROCESSOR_URL};
    }

    location / {
        proxy_pass ${WEB_FRONTEND_URL};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
}

write_state_compose() {
  mkdir -p "${STATE_DIR}"
  mkdir -p "${STATE_DIR}/nats"
  cat > "${STATE_DIR}/nats/nats.conf" <<'EOF'
port: 4222
http: 8222

websocket {
  port: 8081
  no_tls: true
}
EOF

  cat > "${COMPOSE_FILE}" <<'EOF'
name: traderx-state-007

services:
  database:
    build:
      context: ../database
      dockerfile: Dockerfile.compose
    environment:
      DATABASE_TCP_PORT: "18082"
      DATABASE_PG_PORT: "18083"
      DATABASE_WEB_PORT: "18084"
      DATABASE_WEB_HOSTNAMES: "localhost,database"
    ports:
      - "18082:18082"
      - "18083:18083"
      - "18084:18084"

  reference-data:
    build:
      context: ../reference-data
      dockerfile: Dockerfile.compose
    environment:
      REFERENCE_DATA_SERVICE_PORT: "18085"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18085:18085"
    depends_on:
      - database

  nats-broker:
    image: nats:2.10-alpine
    command: ["-c", "/etc/nats/nats.conf"]
    volumes:
      - ./nats/nats.conf:/etc/nats/nats.conf:ro
    ports:
      - "4222:4222"
      - "8222:8222"
      - "8081:8081"

  people-service:
    build:
      context: ../people-service
      dockerfile: Dockerfile.compose
    environment:
      PEOPLE_SERVICE_PORT: "18089"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18089:18089"

  account-service:
    build:
      context: ../account-service
      dockerfile: Dockerfile.compose
    environment:
      ACCOUNT_SERVICE_PORT: "18088"
      DATABASE_TCP_HOST: "database"
      DATABASE_TCP_PORT: "18082"
      PEOPLE_SERVICE_HOST: "people-service"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18088:18088"
    depends_on:
      - database
      - people-service

  position-service:
    build:
      context: ../position-service
      dockerfile: Dockerfile.compose
    environment:
      POSITION_SERVICE_PORT: "18090"
      DATABASE_TCP_HOST: "database"
      DATABASE_TCP_PORT: "18082"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18090:18090"
    depends_on:
      - database

  trade-processor:
    build:
      context: ../trade-processor
      dockerfile: Dockerfile.compose
    environment:
      TRADE_PROCESSOR_SERVICE_PORT: "18091"
      DATABASE_TCP_HOST: "database"
      DATABASE_TCP_PORT: "18082"
      NATS_BROKER_HOST: "nats-broker"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18091:18091"
    depends_on:
      - database
      - nats-broker

  trade-service:
    build:
      context: ../trade-service
      dockerfile: Dockerfile.compose
    environment:
      TRADING_SERVICE_PORT: "18092"
      ACCOUNT_SERVICE_HOST: "account-service"
      REFERENCE_DATA_HOST: "reference-data"
      PEOPLE_SERVICE_HOST: "people-service"
      NATS_BROKER_HOST: "nats-broker"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18092:18092"
    depends_on:
      - account-service
      - reference-data
      - people-service
      - nats-broker
      - trade-processor

  web-front-end-angular:
    build:
      context: ../web-front-end/angular
      dockerfile: Dockerfile.compose
    environment:
      WEB_SERVICE_PORT: "18093"
    ports:
      - "18093:18093"
    depends_on:
      - account-service
      - reference-data
      - trade-service
      - position-service
      - people-service
      - nats-broker

  ingress:
    build:
      context: ../ingress
      dockerfile: Dockerfile.compose
    environment:
      NGINX_HOST: "localhost"
      DATABASE_URL: "http://database:18084/"
      REFERENCE_DATA_URL: "http://reference-data:18085/"
      PEOPLE_SERVICE_URL: "http://people-service:18089/"
      ACCOUNT_SERVICE_URL: "http://account-service:18088/"
      POSITION_SERVICE_URL: "http://position-service:18090/"
      TRADE_PROCESSOR_URL: "http://trade-processor:18091/"
      TRADE_SERVICE_URL: "http://trade-service:18092/"
      WEB_FRONTEND_URL: "http://web-front-end-angular:18093/"
    ports:
      - "8080:8080"
    depends_on:
      - web-front-end-angular
      - account-service
      - reference-data
      - trade-service
      - position-service
      - people-service
      - nats-broker
EOF

  cat > "${STATE_DIR}/README.md" <<'EOF'
# State 007 Messaging NATS Replacement Runtime

Generated compose runtime for:

- `specs/007-messaging-nats-replacement`

Run:

```bash
docker compose -f docker-compose.yml up -d --build
```

Entrypoints:

- UI/ingress: `http://localhost:8080`
- NATS monitor: `http://localhost:8222/varz`
- NATS websocket (ingress proxied): `ws://localhost:8080/nats-ws`
EOF
}

write_trade_service_overlay
write_trade_processor_overlay
write_web_overlay
write_ingress_overlay
write_state_compose

# State 007 removes Socket.IO trade-feed runtime component from the runtime assembly.
rm -rf "${TARGET}/trade-feed"
rm -rf "${TARGET}/containerized-compose"

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=007-messaging-nats-replacement
[summary] parent-state=003-containerized-compose-runtime
[summary] impacted-components=trade-service,trade-processor,web-front-end-angular,ingress
[summary] replaced-component=trade-feed -> nats-broker
[summary] impacted-assets=compose-runtime,ingress-ws-route,nats-client-wiring
[summary] generated-path=generated/code/target-generated/messaging-nats-replacement
[summary] runtime-entrypoint=./scripts/start-state-007-messaging-nats-replacement-generated.sh
EOF
