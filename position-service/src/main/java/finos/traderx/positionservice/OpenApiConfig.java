package finos.traderx.positionservice;
import io.swagger.v3.oas.models.servers.Server;
import io.swagger.v3.oas.models.OpenAPI;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;



@Configuration
public class OpenApiConfig {

@Bean
public OpenAPI config() {
    return new OpenAPI()
            .addServersItem(serverInfo());
}

private Server serverInfo() {
    return new Server()
            .url("");
}
}