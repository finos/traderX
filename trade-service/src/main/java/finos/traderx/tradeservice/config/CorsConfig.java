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
