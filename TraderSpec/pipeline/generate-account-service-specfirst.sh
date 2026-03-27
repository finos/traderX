#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/account-service-specfirst"
GRADLE_WRAPPER_TEMPLATE="${ROOT}/templates/gradle-wrapper"

rm -rf "${TARGET}"
mkdir -p \
  "${TARGET}/gradle/wrapper" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/config" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/controller" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/exceptions" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/model" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/repository" \
  "${TARGET}/src/main/java/finos/traderx/accountservice/service" \
  "${TARGET}/src/main/test/java/finos/traderx/accountservice" \
  "${TARGET}/src/main/resources"

cat <<'EOF' > "${TARGET}/README.md"
# Account-Service (Spec-First Generated)

This component is generated from TraderSpec requirements for the baseline, pre-containerized runtime.

## Run

```bash
./gradlew build
./gradlew bootRun
```

## Runtime Contract

- Default port: `18088` via `ACCOUNT_SERVICE_PORT`
- Database: `DATABASE_TCP_HOST`, `DATABASE_TCP_PORT`, `DATABASE_NAME`, `DATABASE_DBUSER`, `DATABASE_DBPASS`
- People service: `PEOPLE_SERVICE_URL` or `PEOPLE_SERVICE_HOST`
- CORS allowlist: `CORS_ALLOWED_ORIGINS` (default `*`)
EOF

cat <<'EOF' > "${TARGET}/settings.gradle"
rootProject.name = 'account-service-specfirst'
EOF

cat <<'EOF' > "${TARGET}/build.gradle"
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/AccountServiceApplication.java"
package finos.traderx.accountservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AccountServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(AccountServiceApplication.class, args);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/OpenApiConfig.java"
package finos.traderx.accountservice;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

  @Value("${server.port}")
  private int port = 18088;

  @Bean
  public OpenAPI config() {
    Info info = new Info()
        .title("FINOS TraderX Account Service")
        .version("0.1.0")
        .description("Service for account and account-user mapping operations.");

    OpenAPI api = new OpenAPI()
        .addServersItem(serverInfo("", "Empty URL to support proxied docs"))
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/config/CorsConfig.java"
package finos.traderx.accountservice.config;

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/model/Account.java"
package finos.traderx.accountservice.model;

public class Account {
  private Integer id;
  private String displayName;

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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/model/AccountUser.java"
package finos.traderx.accountservice.model;

public class AccountUser {
  private Integer accountId;
  private String username;

  public Integer getAccountId() {
    return accountId;
  }

  public void setAccountId(Integer accountId) {
    this.accountId = accountId;
  }

  public String getUsername() {
    return username;
  }

  public void setUsername(String username) {
    this.username = username;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/model/Person.java"
package finos.traderx.accountservice.model;

public class Person {
  private String logonId;
  private String fullName;
  private String email;
  private String department;
  private String photoUrl;

  public String getLogonId() {
    return logonId;
  }

  public void setLogonId(String logonId) {
    this.logonId = logonId;
  }

  public String getFullName() {
    return fullName;
  }

  public void setFullName(String fullName) {
    this.fullName = fullName;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getDepartment() {
    return department;
  }

  public void setDepartment(String department) {
    this.department = department;
  }

  public String getPhotoUrl() {
    return photoUrl;
  }

  public void setPhotoUrl(String photoUrl) {
    this.photoUrl = photoUrl;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/exceptions/ResourceNotFoundException.java"
package finos.traderx.accountservice.exceptions;

public class ResourceNotFoundException extends RuntimeException {

  public ResourceNotFoundException(String message) {
    super(message);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/repository/AccountRepository.java"
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
      Integer generatedId = jdbcTemplate.queryForObject("select next value for ACCOUNTS_SEQ", Integer.class);
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

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/repository/AccountUserRepository.java"
package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.AccountUser;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class AccountUserRepository {

  private static final RowMapper<AccountUser> ACCOUNT_USER_ROW_MAPPER = (rs, rowNum) -> {
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(rs.getInt("AccountID"));
    accountUser.setUsername(rs.getString("Username"));
    return accountUser;
  };

  private final JdbcTemplate jdbcTemplate;

  public AccountUserRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<AccountUser> findAll() {
    return jdbcTemplate.query(
        "select AccountID, Username from AccountUsers order by AccountID, Username",
        ACCOUNT_USER_ROW_MAPPER
    );
  }

  public Optional<AccountUser> findByAccountId(int accountId) {
    List<AccountUser> rows = jdbcTemplate.query(
        "select AccountID, Username from AccountUsers where AccountID = ? order by Username",
        ACCOUNT_USER_ROW_MAPPER,
        accountId
    );
    return rows.stream().findFirst();
  }

  public boolean exists(int accountId, String username) {
    Integer count = jdbcTemplate.queryForObject(
        "select count(*) from AccountUsers where AccountID = ? and Username = ?",
        Integer.class,
        accountId,
        username
    );
    return count != null && count > 0;
  }

  public AccountUser save(AccountUser accountUser) {
    if (!exists(accountUser.getAccountId(), accountUser.getUsername())) {
      jdbcTemplate.update(
          "insert into AccountUsers (AccountID, Username) values (?, ?)",
          accountUser.getAccountId(),
          accountUser.getUsername()
      );
    }
    return accountUser;
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/service/AccountService.java"
package finos.traderx.accountservice.service;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.repository.AccountRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class AccountService {

  private final AccountRepository accountRepository;

  public AccountService(AccountRepository accountRepository) {
    this.accountRepository = accountRepository;
  }

  public List<Account> getAllAccount() {
    return accountRepository.findAll();
  }

  public Account getAccountById(int id) {
    return accountRepository.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Account with id " + id + " not found"));
  }

  public Account upsertAccount(Account account) {
    return accountRepository.save(account);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/service/PeopleValidationService.java"
package finos.traderx.accountservice.service;

import finos.traderx.accountservice.model.Person;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@Service
public class PeopleValidationService {

  private static final Logger LOGGER = LoggerFactory.getLogger(PeopleValidationService.class);

  private final RestTemplate restTemplate = new RestTemplate();
  private final String peopleServiceAddress;

  public PeopleValidationService(
      @Value("${people.service.url}") String peopleServiceAddress
  ) {
    this.peopleServiceAddress = peopleServiceAddress;
  }

  public boolean validatePerson(String username) {
    String url = peopleServiceAddress + "/People/GetPerson?LogonId=" + username;
    try {
      ResponseEntity<Person> response = restTemplate.getForEntity(url, Person.class);
      LOGGER.info("Validated person {}", response.getBody());
      return true;
    } catch (HttpClientErrorException ex) {
      if (ex.getStatusCode().value() == 404) {
        LOGGER.info("{} not found in people-service", username);
      } else {
        LOGGER.error("people-service lookup failed: {}", ex.getMessage());
      }
      return false;
    }
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/service/AccountUserService.java"
package finos.traderx.accountservice.service;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.repository.AccountRepository;
import finos.traderx.accountservice.repository.AccountUserRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class AccountUserService {

  private final AccountUserRepository accountUserRepository;
  private final AccountRepository accountRepository;

  public AccountUserService(
      AccountUserRepository accountUserRepository,
      AccountRepository accountRepository
  ) {
    this.accountUserRepository = accountUserRepository;
    this.accountRepository = accountRepository;
  }

  public List<AccountUser> getAllAccountUsers() {
    return accountUserRepository.findAll();
  }

  public AccountUser getAccountUserById(int id) {
    return accountUserRepository.findByAccountId(id)
        .orElseThrow(() -> new ResourceNotFoundException("AccountUser with id " + id + " not found"));
  }

  public AccountUser upsertAccountUser(AccountUser accountUser) {
    if (accountUser.getAccountId() == null || !accountRepository.existsById(accountUser.getAccountId())) {
      throw new ResourceNotFoundException("Account with id " + accountUser.getAccountId() + " not found");
    }
    return accountUserRepository.save(accountUser);
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/controller/AccountController.java"
package finos.traderx.accountservice.controller;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.service.AccountService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin("*")
@RestController
@RequestMapping(value = "/account", produces = "application/json")
public class AccountController {

  private final AccountService accountService;

  public AccountController(AccountService accountService) {
    this.accountService = accountService;
  }

  @GetMapping("/{id}")
  public ResponseEntity<Account> getAccountById(@PathVariable int id) {
    return ResponseEntity.ok(accountService.getAccountById(id));
  }

  @PostMapping("/")
  public ResponseEntity<Account> createAccount(@RequestBody Account account) {
    return ResponseEntity.ok(accountService.upsertAccount(account));
  }

  @PutMapping("/")
  public ResponseEntity<Account> updateAccount(@RequestBody Account account) {
    return ResponseEntity.ok(accountService.upsertAccount(account));
  }

  @GetMapping("/")
  public ResponseEntity<List<Account>> getAllAccount() {
    return ResponseEntity.ok(accountService.getAllAccount());
  }

  @ExceptionHandler(ResourceNotFoundException.class)
  public ResponseEntity<String> resourceNotFoundExceptionMapper(ResourceNotFoundException e) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/controller/AccountUserController.java"
package finos.traderx.accountservice.controller;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.service.AccountUserService;
import finos.traderx.accountservice.service.PeopleValidationService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@CrossOrigin("*")
@RestController
@RequestMapping(value = "/accountuser", produces = "application/json")
public class AccountUserController {

  private final AccountUserService accountUserService;
  private final PeopleValidationService peopleValidationService;

  public AccountUserController(
      AccountUserService accountUserService,
      PeopleValidationService peopleValidationService
  ) {
    this.accountUserService = accountUserService;
    this.peopleValidationService = peopleValidationService;
  }

  @GetMapping("/{id}")
  public ResponseEntity<AccountUser> getAccountUserById(@PathVariable int id) {
    return ResponseEntity.ok(accountUserService.getAccountUserById(id));
  }

  @PostMapping("/")
  public ResponseEntity<AccountUser> createAccountUser(@RequestBody AccountUser accountUser) {
    if (!peopleValidationService.validatePerson(accountUser.getUsername())) {
      throw new ResourceNotFoundException(accountUser.getUsername() + " not found in People service.");
    }
    return ResponseEntity.ok(accountUserService.upsertAccountUser(accountUser));
  }

  @PutMapping("/")
  public ResponseEntity<AccountUser> updateAccountUser(@RequestBody AccountUser accountUser) {
    return ResponseEntity.ok(accountUserService.upsertAccountUser(accountUser));
  }

  @GetMapping("/")
  public ResponseEntity<List<AccountUser>> getAllAccountUsers() {
    return ResponseEntity.ok(accountUserService.getAllAccountUsers());
  }

  @ExceptionHandler(ResourceNotFoundException.class)
  public ResponseEntity<String> resourceNotFoundExceptionMapper(ResourceNotFoundException e) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<String> generalError(Exception e) {
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
  }
}
EOF

cat <<'EOF' > "${TARGET}/src/main/java/finos/traderx/accountservice/controller/DocsController.java"
package finos.traderx.accountservice.controller;

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
server.port=${ACCOUNT_SERVICE_PORT:18088}

spring.datasource.url=jdbc:h2:tcp://${DATABASE_TCP_HOST:localhost}:${DATABASE_TCP_PORT:18082}/${DATABASE_NAME:traderx};CASE_INSENSITIVE_IDENTIFIERS=TRUE
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=${DATABASE_DBUSER:sa}
spring.datasource.password=${DATABASE_DBPASS:sa}
spring.threads.virtual.enabled=true

people.service.url=${PEOPLE_SERVICE_URL:http://${PEOPLE_SERVICE_HOST:localhost}:18089}

server.max-http-request-header-size=1000000
EOF

cat <<'EOF' > "${TARGET}/src/main/resources/test-application.properties"
server.port=0
spring.datasource.url=jdbc:h2:mem:testdb;MODE=LEGACY
spring.datasource.driverClassName=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=sa
people.service.url=http://localhost:18089
EOF

cat <<'EOF' > "${TARGET}/src/main/test/java/finos/traderx/accountservice/AccountServiceApplicationTests.java"
package finos.traderx.accountservice;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class AccountServiceApplicationTests {

  @Test
  void contextLoads() {
    // smoke test
  }
}
EOF

cat <<'EOF' > "${TARGET}/openapi.yaml"
openapi: 3.0.1
info:
  title: "Account Service - TraderX Spec-First"
  version: "1.0"
paths:
  /account/:
    get:
      responses:
        "200":
          description: OK
    post:
      responses:
        "200":
          description: OK
    put:
      responses:
        "200":
          description: OK
  /account/{id}:
    get:
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        "200":
          description: OK
        "404":
          description: Not found
  /accountuser/:
    get:
      responses:
        "200":
          description: OK
    post:
      responses:
        "200":
          description: OK
        "404":
          description: Person not found
    put:
      responses:
        "200":
          description: OK
  /accountuser/{id}:
    get:
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        "200":
          description: OK
        "404":
          description: Not found
EOF

cat <<'EOF' > "${TARGET}/Dockerfile"
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18088
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF

cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew" "${TARGET}/gradlew"
cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew.bat" "${TARGET}/gradlew.bat"
cp -R "${GRADLE_WRAPPER_TEMPLATE}/gradle/wrapper/"* "${TARGET}/gradle/wrapper/"
chmod +x "${TARGET}/gradlew"

echo "[done] regenerated ${TARGET}"
