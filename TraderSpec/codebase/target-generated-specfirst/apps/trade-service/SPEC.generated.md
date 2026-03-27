# trade-service

- kind: service
- sourcePath: trade-service
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18092
- dependsOn: account-service|reference-data|people-service|trade-feed
- requiredEnv: ACCOUNT_SERVICE_HOST|REFERENCE_DATA_HOST|PEOPLE_SERVICE_HOST|TRADE_FEED_HOST

Notes:
"Validates and publishes new trade orders."
