# trade-processor

- kind: service
- sourcePath: trade-processor
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18091
- dependsOn: database|trade-feed
- requiredEnv: DATABASE_TCP_HOST|TRADE_FEED_HOST

Notes:
"Consumes /trades topic and publishes account trade/position updates."
