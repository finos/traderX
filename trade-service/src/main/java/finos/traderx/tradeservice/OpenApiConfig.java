package finos.traderx.tradeservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;

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