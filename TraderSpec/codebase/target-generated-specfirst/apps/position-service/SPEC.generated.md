# position-service

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/position-service-specfirst
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18090
- dependsOn: database
- requiredEnv: POSITION_SERVICE_PORT|DATABASE_TCP_HOST|DATABASE_TCP_PORT|DATABASE_NAME|DATABASE_DBUSER|DATABASE_DBPASS|CORS_ALLOWED_ORIGINS

Notes:
"Trades/positions read model APIs."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-003 story=US-002 acceptance=AC-003 flow=F2
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
