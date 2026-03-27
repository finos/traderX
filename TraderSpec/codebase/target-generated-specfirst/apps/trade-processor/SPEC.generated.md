# trade-processor

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/trade-processor-specfirst
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18091
- dependsOn: database|trade-feed
- requiredEnv: TRADE_PROCESSOR_SERVICE_PORT|DATABASE_TCP_HOST|DATABASE_TCP_PORT|DATABASE_NAME|DATABASE_DBUSER|DATABASE_DBPASS|TRADE_FEED_ADDRESS|TRADE_FEED_HOST|CORS_ALLOWED_ORIGINS

Notes:
"Consumes /trades topic, persists trades/positions, and publishes account trade/position updates."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-007 story=US-004 acceptance=AC-005 flow=F4
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
