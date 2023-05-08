package finos.traderx.tradeprocessor;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;

@Configuration
public class OpenApiConfig {

    @Value("${server.port}")
    private int port = 18091;

    @Bean
    public OpenAPI config() {
        Info info = new Info()
                .title("FINOS TraderX Trading Processor")
                .version("0.1.0")
                .description("Service for processing trades from the Trade Feed, Persisting trades, updating positions, and Publishing updates to the feed");

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