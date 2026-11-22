package finos.traderx.ordermatcher;

import finos.traderx.ordermatcher.api.OrderCreateRequest;
import finos.traderx.ordermatcher.model.OrderSide;
import finos.traderx.ordermatcher.model.OrderStatus;
import finos.traderx.ordermatcher.model.OrderType;
import finos.traderx.ordermatcher.service.OrderMatcherService;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.io.FileSystemResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named = "TRADERX_TEST_POSTGRES_URL", matches = ".+")
class OrderBookPostgresUpgradeTest {
    private final String baseUrl = System.getenv("TRADERX_TEST_POSTGRES_URL");
    private final String user = System.getenv("TRADERX_TEST_POSTGRES_USER");
    private final String password = System.getenv("TRADERX_TEST_POSTGRES_PASSWORD");

    @Test
    void populatedLegacyDatabaseUpgradesBeforeJpaAndSurvivesRestart() throws Exception {
        inIsolatedSchema(url -> {
            try (Connection connection = connect(url); var sql = connection.createStatement()) {
                // The pre-MARKET OrderBook layout, with a real outstanding order.
                sql.execute("""
                    CREATE TABLE orderbook (
                        orderid VARCHAR(32) PRIMARY KEY, accountid INTEGER NOT NULL,
                        security VARCHAR(16) NOT NULL, side VARCHAR(16),
                        quantity INTEGER NOT NULL, remainingquantity INTEGER NOT NULL,
                        limitprice DECIMAL(18,3) NOT NULL, status VARCHAR(24),
                        createdat TIMESTAMP NOT NULL, updatedat TIMESTAMP NOT NULL,
                        lastexecutionprice DECIMAL(18,3), lastfillquantity INTEGER
                    )
                    """);
                sql.execute("""
                    INSERT INTO orderbook VALUES ('ord-013-0001',22214,'IBM','Buy',10,10,
                        100,'NEW','2026-11-01 12:00:00','2026-11-01 12:00:00',NULL,NULL)
                    """);
            }
            for (int restart = 0; restart < 2; restart++) {
                try (ConfigurableApplicationContext context = start(url)) {
                    var service = context.getBean(OrderMatcherService.class);
                    var legacy = service.getOrder("ord-013-0001");
                    assertEquals(OrderType.LIMIT, legacy.getOrderType());
                    assertEquals(10, legacy.getRemainingQuantity());
                    assertEquals(OrderStatus.NEW, legacy.getStatus());
                    assertEquals("2026-11-01T12:00:00Z", legacy.getCreatedAt().toString());
                    assertEquals(0, legacy.getLimitPrice().compareTo(new java.math.BigDecimal("100")));
                    assertMarketPersists(service);
                    assertColumnContract(url);
                }
            }
        });
    }

    @Test
    void freshGeneratedSchemaAcceptsMarketAndRetainsConstraints() throws Exception {
        inIsolatedSchema(url -> {
            try (Connection connection = connect(url)) {
                // Consume the generated production schema, not a copied SQLite surrogate.
                ScriptUtils.executeSqlScript(connection, new FileSystemResource(
                    Path.of("..", "conformance", "state-009", "fresh-init.sql")));
            }
            try (ConfigurableApplicationContext context = start(url)) {
                assertMarketPersists(context.getBean(OrderMatcherService.class));
                assertColumnContract(url);
            }
        });
    }

    private void assertMarketPersists(OrderMatcherService service) {
        var request = new OrderCreateRequest();
        request.setAccountId(22214);
        request.setSecurity("IBM");
        request.setSide(OrderSide.Buy);
        request.setQuantity(10);
        request.setOrderType(OrderType.MARKET);
        var created = service.createOrder(request);
        var loaded = service.getOrder(created.getOrderId());
        assertEquals(OrderType.MARKET, loaded.getOrderType());
        assertNull(loaded.getLimitPrice());
        assertEquals(OrderStatus.NEW, loaded.getStatus());
    }

    private void assertColumnContract(String url) throws Exception {
        try (Connection connection = connect(url); var sql = connection.createStatement()) {
            sql.execute("""
                INSERT INTO orderbook (orderid,accountid,security,side,quantity,remainingquantity,
                    limitprice,status,createdat,updatedat)
                VALUES ('default-type',22214,'IBM','Buy',1,1,100,'NEW',NOW(),NOW())
                """);
            try (var result = sql.executeQuery("SELECT ordertype FROM orderbook WHERE orderid='default-type'")) {
                assertTrue(result.next());
                assertEquals("LIMIT", result.getString(1));
            }
            SQLException invalidType = assertThrows(SQLException.class,
                () -> sql.execute("UPDATE orderbook SET ordertype='INVALID' WHERE orderid='default-type'"));
            assertEquals("23514", invalidType.getSQLState());
            SQLException nullType = assertThrows(SQLException.class,
                () -> sql.execute("UPDATE orderbook SET ordertype=NULL WHERE orderid='default-type'"));
            assertEquals("23502", nullType.getSQLState());
            sql.execute("DELETE FROM orderbook WHERE orderid='default-type'");
        }
    }

    private ConfigurableApplicationContext start(String url) {
        // Load production initialization settings, not the H2 test configuration.
        return new SpringApplicationBuilder(OrderMatcherApplication.class)
            .web(WebApplicationType.NONE).run(
                "--spring.config.location=file:src/main/resources/application.properties",
                "--spring.datasource.url=" + url,
                "--spring.datasource.username=" + user,
                "--spring.datasource.password=" + password,
                "--spring.jpa.properties.hibernate.jdbc.time_zone=UTC",
                "--order.matcher.publisher=noop",
                "--order.matcher.pricing-subscriber.enabled=false",
                "--order.matcher.seed-enabled=false",
                "--management.otlp.metrics.export.enabled=false");
    }

    private Connection connect(String url) throws SQLException {
        return DriverManager.getConnection(url, user, password);
    }

    private void inIsolatedSchema(DatabaseCheck check) throws Exception {
        String schema = "review_" + UUID.randomUUID().toString().replace("-", "");
        try (Connection connection = connect(baseUrl); var sql = connection.createStatement()) {
            sql.execute("CREATE SCHEMA " + schema);
            try {
                check.run(baseUrl + (baseUrl.contains("?") ? "&" : "?") + "currentSchema=" + schema);
            } finally {
                sql.execute("DROP SCHEMA " + schema + " CASCADE");
            }
        }
    }

    @FunctionalInterface
    private interface DatabaseCheck { void run(String url) throws Exception; }
}
