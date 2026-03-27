# trade-service

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/trade-service-specfirst
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18092
- dependsOn: account-service|reference-data|people-service|trade-feed|trade-processor
- requiredEnv: TRADING_SERVICE_PORT|ACCOUNT_SERVICE_URL|ACCOUNT_SERVICE_HOST|REFERENCE_DATA_SERVICE_URL|REFERENCE_DATA_HOST|PEOPLE_SERVICE_URL|PEOPLE_SERVICE_HOST|TRADE_FEED_ADDRESS|TRADE_FEED_HOST|CORS_ALLOWED_ORIGINS

Notes:
"Validates account+ticker and publishes new trade orders to /trades."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-006 story=US-003 acceptance=AC-004 flow=F3
- requirement=SYS-FR-010 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
- requirement=SYS-NFR-007 story=US-009 acceptance=AC-009 flow=STARTUP
