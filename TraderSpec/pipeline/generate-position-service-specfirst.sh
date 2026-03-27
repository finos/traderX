#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/position-service-specfirst"
GRADLE_WRAPPER_TEMPLATE="${ROOT}/templates/gradle-wrapper"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/gradle/wrapper" \
  "${TARGET}/src/main/java/finos/traderx/positionservice/config" \
  "${TARGET}/src/main/java/finos/traderx/positionservice/controller" \
  "${TARGET}/src/main/java/finos/traderx/positionservice/model" \
  "${TARGET}/src/main/java/finos/traderx/positionservice/repository" \
  "${TARGET}/src/main/java/finos/traderx/positionservice/service" \
  "${TARGET}/src/main/test/java/finos/traderx/positionservice" \
  "${TARGET}/src/main/resources"

cat <<'EOF' > "${TARGET}/README.md"
# Position-Service (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18090` via `POSITION_SERVICE_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
EOF

cat <<'EOF' > "${TARGET}/settings.gradle"
rootProject.name = 'position-service-specfirst'
EOF

cat <<'EOF' > "${TARGET}/build.gradle"
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.3'
  id 'io.spring.dependency-management' version '1.1.7'
}

group = 'finos.traderx.position-service-specfirst'
version = '0.1.0'

java {
  sourceCompatibility = JavaVersion.VERSION_21
}

repositories {
  mavenCentral()
}

dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
  implementation 'org.springframework.boot:spring-boot-starter-jdbc'
  implementation 'com.h2database:h2:2.3.232'
  implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.6'

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/PositionServiceApplication.java"
package finos.traderx.positionservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class PositionServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(PositionServiceApplication.class, args);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/OpenApiConfig.java"
package finos.traderx.positionservice;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

  @Value("${server.port}")
  private int port = 18090;

  @Bean
  public OpenAPI config() {
    Info info = new Info()
        .title("FINOS TraderX Position Service")
        .version("0.1.0")
        .description("Service for retrieving blotter data, for trades and positions");

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/config/CorsConfig.java"
package finos.traderx.positionservice.config;

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/model/Trade.java"
package finos.traderx.positionservice.model;

import java.util.Date;

public class Trade {
  private String id;
  private Integer accountId;
  private String security;
  private String side;
  private String state;
  private Integer quantity;
  private Date updated;
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

  public String getSide() {
    return side;
  }

  public void setSide(String side) {
    this.side = side;
  }

  public String getState() {
    return state;
  }

  public void setState(String state) {
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/model/Position.java"
package finos.traderx.positionservice.model;

import java.util.Date;

public class Position {
  private Integer accountId;
  private String security;
  private Integer quantity;
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/repository/TradeRepository.java"
package finos.traderx.positionservice.repository;

import finos.traderx.positionservice.model.Trade;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class TradeRepository {

  private static final RowMapper<Trade> TRADE_ROW_MAPPER = (rs, rowNum) -> {
    Trade trade = new Trade();
    trade.setId(rs.getString("ID"));
    trade.setAccountId(rs.getInt("AccountID"));
    trade.setSecurity(rs.getString("Security"));
    trade.setSide(rs.getString("Side"));
    trade.setState(rs.getString("State"));
    trade.setQuantity(rs.getInt("Quantity"));
    trade.setUpdated(rs.getTimestamp("Updated"));
    trade.setCreated(rs.getTimestamp("Created"));
    return trade;
  };

  private final JdbcTemplate jdbcTemplate;

  public TradeRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Trade> findAll() {
    return jdbcTemplate.query(
        "select ID, AccountID, Security, Side, State, Quantity, Updated, Created from Trades order by Updated desc",
        TRADE_ROW_MAPPER
    );
  }

  public List<Trade> findByAccountId(int accountId) {
    return jdbcTemplate.query(
        "select ID, AccountID, Security, Side, State, Quantity, Updated, Created from Trades where AccountID = ? order by Updated desc",
        TRADE_ROW_MAPPER,
        accountId
    );
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/repository/PositionRepository.java"
package finos.traderx.positionservice.repository;

import finos.traderx.positionservice.model.Position;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class PositionRepository {

  private static final RowMapper<Position> POSITION_ROW_MAPPER = (rs, rowNum) -> {
    Position position = new Position();
    position.setAccountId(rs.getInt("AccountID"));
    position.setSecurity(rs.getString("Security"));
    position.setQuantity(rs.getInt("Quantity"));
    position.setUpdated(rs.getTimestamp("Updated"));
    return position;
  };

  private final JdbcTemplate jdbcTemplate;

  public PositionRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Position> findAll() {
    return jdbcTemplate.query(
        "select AccountID, Security, Quantity, Updated from Positions order by AccountID, Security",
        POSITION_ROW_MAPPER
    );
  }

  public List<Position> findByAccountId(int accountId) {
    return jdbcTemplate.query(
        "select AccountID, Security, Quantity, Updated from Positions where AccountID = ? order by Security",
        POSITION_ROW_MAPPER,
        accountId
    );
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/service/TradeService.java"
package finos.traderx.positionservice.service;

import finos.traderx.positionservice.model.Trade;
import finos.traderx.positionservice.repository.TradeRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class TradeService {

  private final TradeRepository tradeRepository;

  public TradeService(TradeRepository tradeRepository) {
    this.tradeRepository = tradeRepository;
  }

  public List<Trade> getAllTrades() {
    return tradeRepository.findAll();
  }

  public List<Trade> getTradesByAccountID(int accountId) {
    return tradeRepository.findByAccountId(accountId);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/service/PositionService.java"
package finos.traderx.positionservice.service;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.repository.PositionRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class PositionService {

  private final PositionRepository positionRepository;

  public PositionService(PositionRepository positionRepository) {
    this.positionRepository = positionRepository;
  }

  public List<Position> getAllPositions() {
    return positionRepository.findAll();
  }

  public List<Position> getPositionsByAccountID(int accountId) {
    return positionRepository.findByAccountId(accountId);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/controller/TradeController.java"
package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.model.Trade;
import finos.traderx.positionservice.service.TradeService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/trades", produces = "application/json")
public class TradeController {

  private final TradeService tradeService;

  public TradeController(TradeService tradeService) {
    this.tradeService = tradeService;
  }

  @GetMapping("/{accountId}")
  public ResponseEntity<List<Trade>> getByAccountId(@PathVariable int accountId) {
    return ResponseEntity.ok(tradeService.getTradesByAccountID(accountId));
  }

  @GetMapping("/")
  public ResponseEntity<List<Trade>> getAllTrades() {
    return ResponseEntity.ok(tradeService.getAllTrades());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/controller/PositionController.java"
package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.service.PositionService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/positions", produces = "application/json")
public class PositionController {

  private final PositionService positionService;

  public PositionController(PositionService positionService) {
    this.positionService = positionService;
  }

  @GetMapping("/{accountId}")
  public ResponseEntity<List<Position>> getByAccountId(@PathVariable int accountId) {
    return ResponseEntity.ok(positionService.getPositionsByAccountID(accountId));
  }

  @GetMapping("/")
  public ResponseEntity<List<Position>> getAllPositions() {
    return ResponseEntity.ok(positionService.getAllPositions());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/controller/HealthController.java"
package finos.traderx.positionservice.controller;

import finos.traderx.positionservice.service.PositionService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/health", produces = "application/json")
public class HealthController {

  private final PositionService positionService;

  public HealthController(PositionService positionService) {
    this.positionService = positionService;
  }

  @GetMapping("/ready")
  public ResponseEntity<Boolean> isReady() {
    return ResponseEntity.ok(positionService.getAllPositions().size() > 0);
  }

  @GetMapping("/alive")
  public ResponseEntity<Boolean> isAlive() {
    return ResponseEntity.ok(true);
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/positionservice/controller/DocsController.java"
package finos.traderx.positionservice.controller;

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

cat <<'EOF' > "${TARGET}/src/main/resources/application.properties"
server.port=${POSITION_SERVICE_PORT:18090}

spring.datasource.url=jdbc:h2:tcp://${DATABASE_TCP_HOST:localhost}:${DATABASE_TCP_PORT:18082}/${DATABASE_NAME:traderx};CASE_INSENSITIVE_IDENTIFIERS=TRUE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=${DATABASE_DBUSER:sa}
spring.datasource.password=${DATABASE_DBPASS:sa}
spring.threads.virtual.enabled=true

server.max-http-request-header-size=1000000
EOF

cat <<'EOF' > "${TARGET}/src/main/resources/test-application.properties"
server.port=0
spring.datasource.url=jdbc:h2:mem:testdb;MODE=LEGACY
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=sa
EOF

cat <<'EOF' > "${TARGET}/src/main/test/java/finos/traderx/positionservice/PositionServiceApplicationTests.java"
package finos.traderx.positionservice;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class PositionServiceApplicationTests {

  @Test
  void contextLoads() {
    // smoke test
  }
}
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.1
info:
  title: FINOS TraderX Position Service (Spec-First)
  version: 0.1.0
paths:
  /trades/{accountId}:
    get:
      responses:
        "200":
          description: OK
  /trades/:
    get:
      responses:
        "200":
          description: OK
  /positions/{accountId}:
    get:
      responses:
        "200":
          description: OK
  /positions/:
    get:
      responses:
        "200":
          description: OK
  /health/ready:
    get:
      responses:
        "200":
          description: OK
  /health/alive:
    get:
      responses:
        "200":
          description: OK
EOF

cat <<'EOF' > "${TARGET}/Dockerfile"
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18090
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF

cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew" "${TARGET}/gradlew"
cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew.bat" "${TARGET}/gradlew.bat"
cp -R "${GRADLE_WRAPPER_TEMPLATE}/gradle/wrapper/"* "${TARGET}/gradle/wrapper/"
chmod +x "${TARGET}/gradlew"

echo "[done] regenerated ${TARGET}"
