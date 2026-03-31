#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="009-postgres-database-replacement"
PARENT_STATE_ID="003-containerized-compose-runtime"
TARGET="${ROOT}/generated/code/target-generated"
STATE_DIR="${TARGET}/postgres-database-replacement"
COMPOSE_FILE="${STATE_DIR}/docker-compose.yml"
POSTGRES_INIT_DIR="${STATE_DIR}/postgres-init"
SPEC_SOURCE_DIR="${STATE_DIR}/spec-source"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"

[[ -d "${TARGET}" ]] || {
  echo "[fail] missing target output: ${TARGET}"
  exit 1
}

write_account_overlay() {
  local svc="${TARGET}/account-service"

  cat > "${svc}/build.gradle" <<'EOF'
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.3'
  id 'io.spring.dependency-management' version '1.1.7'
}

group = 'finos.traderx.account-service-specfirst'
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
  implementation 'org.postgresql:postgresql:42.7.4'
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

  cat > "${svc}/src/main/resources/application.properties" <<'EOF'
server.port=${ACCOUNT_SERVICE_PORT:18088}

spring.datasource.url=jdbc:postgresql://${DATABASE_PG_HOST:localhost}:${DATABASE_PG_PORT:5432}/${DATABASE_NAME:traderx}
spring.datasource.driverClassName=org.postgresql.Driver
spring.datasource.username=${DATABASE_DBUSER:traderx}
spring.datasource.password=${DATABASE_DBPASS:traderx}
spring.threads.virtual.enabled=true

people.service.url=${PEOPLE_SERVICE_URL:http://${PEOPLE_SERVICE_HOST:localhost}:18089}

server.max-http-request-header-size=1000000
EOF

  cat > "${svc}/src/main/java/finos/traderx/accountservice/repository/AccountRepository.java" <<'EOF'
package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.Account;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class AccountRepository {

  private static final RowMapper<Account> ACCOUNT_ROW_MAPPER = (rs, rowNum) -> {
    Account account = new Account();
    account.setId(rs.getInt("ID"));
    account.setDisplayName(rs.getString("DisplayName"));
    return account;
  };

  private final JdbcTemplate jdbcTemplate;

  public AccountRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Account> findAll() {
    return jdbcTemplate.query(
        "select ID, DisplayName from Accounts order by ID",
        ACCOUNT_ROW_MAPPER
    );
  }

  public Optional<Account> findById(int id) {
    List<Account> rows = jdbcTemplate.query(
        "select ID, DisplayName from Accounts where ID = ?",
        ACCOUNT_ROW_MAPPER,
        id
    );
    return rows.stream().findFirst();
  }

  public Account save(Account account) {
    Integer accountId = account.getId();
    if (accountId == null || accountId <= 0) {
      Integer generatedId = jdbcTemplate.queryForObject("select nextval('accounts_seq')", Integer.class);
      jdbcTemplate.update("insert into Accounts (ID, DisplayName) values (?, ?)", generatedId, account.getDisplayName());
      account.setId(generatedId);
      return account;
    }

    int updated = jdbcTemplate.update(
        "update Accounts set DisplayName = ? where ID = ?",
        account.getDisplayName(),
        accountId
    );

    if (updated == 0) {
      jdbcTemplate.update("insert into Accounts (ID, DisplayName) values (?, ?)", accountId, account.getDisplayName());
    }

    return account;
  }

  public boolean existsById(int id) {
    Integer count = jdbcTemplate.queryForObject(
        "select count(*) from Accounts where ID = ?",
        Integer.class,
        id
    );
    return count != null && count > 0;
  }
}
EOF
}

write_position_overlay() {
  local svc="${TARGET}/position-service"

  cat > "${svc}/build.gradle" <<'EOF'
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
  implementation 'org.postgresql:postgresql:42.7.4'
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

  cat > "${svc}/src/main/resources/application.properties" <<'EOF'
server.port=${POSITION_SERVICE_PORT:18090}

spring.datasource.url=jdbc:postgresql://${DATABASE_PG_HOST:localhost}:${DATABASE_PG_PORT:5432}/${DATABASE_NAME:traderx}
spring.datasource.driverClassName=org.postgresql.Driver
spring.datasource.username=${DATABASE_DBUSER:traderx}
spring.datasource.password=${DATABASE_DBPASS:traderx}
spring.threads.virtual.enabled=true

server.max-http-request-header-size=1000000
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
  implementation 'org.postgresql:postgresql:42.7.4'
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

  cat > "${svc}/src/main/resources/application.properties" <<'EOF'
server.port=${TRADE_PROCESSOR_SERVICE_PORT:18091}

spring.datasource.url=jdbc:postgresql://${DATABASE_PG_HOST:localhost}:${DATABASE_PG_PORT:5432}/${DATABASE_NAME:traderx}
spring.datasource.driverClassName=org.postgresql.Driver
spring.datasource.username=${DATABASE_DBUSER:traderx}
spring.datasource.password=${DATABASE_DBPASS:traderx}
spring.data.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
spring.data.jpa.show-sql=true
spring.jpa.hibernate.ddl-auto=none
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
spring.threads.virtual.enabled=true

trade.feed.address=${TRADE_FEED_ADDRESS:http://${TRADE_FEED_HOST:localhost}:18086}

# To avoid "Request header is too large" when application is backed by oidc proxy.
server.max-http-request-header-size=1000000

logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=DEBUG
EOF
}

write_postgres_runtime_assets() {
  rm -rf "${STATE_DIR}"
  mkdir -p "${POSTGRES_INIT_DIR}" "${SPEC_SOURCE_DIR}"

  cat > "${POSTGRES_INIT_DIR}/initialSchema.sql" <<'EOF'
DROP TABLE IF EXISTS trades;
DROP TABLE IF EXISTS accountusers;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS accounts;
DROP SEQUENCE IF EXISTS accounts_seq;

CREATE TABLE accounts (
  id INTEGER PRIMARY KEY,
  displayname VARCHAR(50)
);

CREATE TABLE accountusers (
  accountid INTEGER NOT NULL,
  username VARCHAR(15) NOT NULL,
  PRIMARY KEY (accountid, username),
  FOREIGN KEY (accountid) REFERENCES accounts(id)
);

CREATE TABLE positions (
  accountid INTEGER,
  security VARCHAR(15),
  updated TIMESTAMP,
  quantity INTEGER,
  PRIMARY KEY (accountid, security),
  FOREIGN KEY (accountid) REFERENCES accounts(id)
);

CREATE TABLE trades (
  id VARCHAR(50) PRIMARY KEY,
  accountid INTEGER REFERENCES accounts(id),
  created TIMESTAMP,
  updated TIMESTAMP,
  security VARCHAR(15),
  side VARCHAR(10) CHECK (side in ('Buy', 'Sell')),
  quantity INTEGER CHECK (quantity > 0),
  state VARCHAR(20) CHECK (state in ('New', 'Processing', 'Settled', 'Cancelled'))
);

CREATE SEQUENCE accounts_seq START WITH 65000 INCREMENT BY 1;

INSERT INTO accounts (id, displayname) VALUES (22214, 'Test Account 20');
INSERT INTO accounts (id, displayname) VALUES (11413, 'Private Clients Fund TTXX');
INSERT INTO accounts (id, displayname) VALUES (42422, 'Algo Execution Partners');
INSERT INTO accounts (id, displayname) VALUES (52355, 'Big Corporate Fund');
INSERT INTO accounts (id, displayname) VALUES (62654, 'Hedge Fund TXY1');
INSERT INTO accounts (id, displayname) VALUES (10031, 'Internal Trading Book');
INSERT INTO accounts (id, displayname) VALUES (44044, 'Trading Account 1');

INSERT INTO accountusers (accountid, username) VALUES (22214, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user03');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user03');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user04');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user06');

INSERT INTO trades (id, created, updated, security, side, quantity, state, accountid) VALUES ('TRADE-22214-AABBCC', NOW(), NOW(), 'IBM', 'Sell', 100, 'Settled', 22214);
INSERT INTO trades (id, created, updated, security, side, quantity, state, accountid) VALUES ('TRADE-22214-DDEEFF', NOW(), NOW(), 'MS', 'Buy', 1000, 'Settled', 22214);
INSERT INTO trades (id, created, updated, security, side, quantity, state, accountid) VALUES ('TRADE-22214-GGHHII', NOW(), NOW(), 'C', 'Sell', 2000, 'Settled', 22214);

INSERT INTO positions (accountid, security, updated, quantity) VALUES (22214, 'MS', NOW(), 1000);
INSERT INTO positions (accountid, security, updated, quantity) VALUES (22214, 'IBM', NOW(), -100);
INSERT INTO positions (accountid, security, updated, quantity) VALUES (22214, 'C', NOW(), -2000);

INSERT INTO trades (id, created, updated, security, side, quantity, state, accountid) VALUES ('TRADE-52355-AABBCC', NOW(), NOW(), 'BAC', 'Sell', 2400, 'Settled', 52355);
INSERT INTO positions (accountid, security, updated, quantity) VALUES (52355, 'BAC', NOW(), -2400);
EOF

  cat > "${COMPOSE_FILE}" <<'EOF'
name: traderx-state-009

services:
  database:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: "traderx"
      POSTGRES_USER: "traderx"
      POSTGRES_PASSWORD: "traderx"
    ports:
      - "18083:5432"
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U traderx -d traderx" ]
      interval: 5s
      timeout: 5s
      retries: 20
    volumes:
      - postgres_state_009_data:/var/lib/postgresql/data
      - ./postgres-init/initialSchema.sql:/docker-entrypoint-initdb.d/001-initialSchema.sql:ro

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

  trade-feed:
    build:
      context: ../trade-feed
      dockerfile: Dockerfile.compose
    environment:
      TRADE_FEED_PORT: "18086"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18086:18086"

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
      DATABASE_PG_HOST: "database"
      DATABASE_PG_PORT: "5432"
      DATABASE_NAME: "traderx"
      DATABASE_DBUSER: "traderx"
      DATABASE_DBPASS: "traderx"
      PEOPLE_SERVICE_HOST: "people-service"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18088:18088"
    depends_on:
      database:
        condition: service_healthy
      people-service:
        condition: service_started

  position-service:
    build:
      context: ../position-service
      dockerfile: Dockerfile.compose
    environment:
      POSITION_SERVICE_PORT: "18090"
      DATABASE_PG_HOST: "database"
      DATABASE_PG_PORT: "5432"
      DATABASE_NAME: "traderx"
      DATABASE_DBUSER: "traderx"
      DATABASE_DBPASS: "traderx"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18090:18090"
    depends_on:
      database:
        condition: service_healthy

  trade-processor:
    build:
      context: ../trade-processor
      dockerfile: Dockerfile.compose
    environment:
      TRADE_PROCESSOR_SERVICE_PORT: "18091"
      DATABASE_PG_HOST: "database"
      DATABASE_PG_PORT: "5432"
      DATABASE_NAME: "traderx"
      DATABASE_DBUSER: "traderx"
      DATABASE_DBPASS: "traderx"
      TRADE_FEED_HOST: "trade-feed"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18091:18091"
    depends_on:
      database:
        condition: service_healthy
      trade-feed:
        condition: service_started

  trade-service:
    build:
      context: ../trade-service
      dockerfile: Dockerfile.compose
    environment:
      TRADING_SERVICE_PORT: "18092"
      ACCOUNT_SERVICE_HOST: "account-service"
      REFERENCE_DATA_HOST: "reference-data"
      PEOPLE_SERVICE_HOST: "people-service"
      TRADE_FEED_HOST: "trade-feed"
      CORS_ALLOWED_ORIGINS: "http://localhost:8080"
    ports:
      - "18092:18092"
    depends_on:
      - account-service
      - reference-data
      - people-service
      - trade-feed
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
      - trade-feed

  ingress:
    build:
      context: ../ingress
      dockerfile: Dockerfile.compose
    environment:
      NGINX_HOST: "localhost"
      DATABASE_URL: "http://database:5432/"
      REFERENCE_DATA_URL: "http://reference-data:18085/"
      TRADE_FEED_URL: "http://trade-feed:18086/"
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
      - trade-feed

volumes:
  postgres_state_009_data:
EOF

  cp "${ROOT}/specs/009-postgres-database-replacement/spec.md" "${SPEC_SOURCE_DIR}/spec.md"
  cp "${ROOT}/specs/009-postgres-database-replacement/requirements/functional-delta.md" "${SPEC_SOURCE_DIR}/functional-delta.md"
  cp "${ROOT}/specs/009-postgres-database-replacement/requirements/nonfunctional-delta.md" "${SPEC_SOURCE_DIR}/nonfunctional-delta.md"
  cp "${ROOT}/specs/009-postgres-database-replacement/contracts/contract-delta.md" "${SPEC_SOURCE_DIR}/contract-delta.md"

  cat > "${STATE_DIR}/README.md" <<'EOF'
# State 009 PostgreSQL Database Replacement

Generated from:

- `specs/009-postgres-database-replacement/**`
- parent state `003-containerized-compose-runtime`

State intent:

- replace H2 runtime database with PostgreSQL while preserving baseline behavior,
- keep edge ingress and Docker Compose runtime model from state 003,
- keep existing REST and messaging contracts stable for baseline flows.

Artifacts:

- Compose runtime: `docker-compose.yml`
- Postgres bootstrap schema/data: `postgres-init/initialSchema.sql`
- Spec references: `spec-source/*`

Run:

```bash
./scripts/start-state-009-postgres-database-replacement-generated.sh
```

Smoke tests:

```bash
./scripts/test-state-009-postgres-database-replacement.sh
```
EOF
}

write_account_overlay
write_position_overlay
write_trade_processor_overlay
write_postgres_runtime_assets

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<EOF
[summary] state=${STATE_ID}
[summary] parent-state=${PARENT_STATE_ID}
[summary] impacted-components=database,account-service,position-service,trade-processor
[summary] impacted-assets=postgres-container,postgres-init-schema,compose-runtime
[summary] generated-path=generated/code/target-generated/postgres-database-replacement
[summary] runtime-entrypoint=./scripts/start-state-009-postgres-database-replacement-generated.sh
EOF
