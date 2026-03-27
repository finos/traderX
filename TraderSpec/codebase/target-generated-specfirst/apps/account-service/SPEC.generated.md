# account-service

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/account-service-specfirst
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18088
- dependsOn: database|people-service
- requiredEnv: ACCOUNT_SERVICE_PORT|DATABASE_TCP_HOST|PEOPLE_SERVICE_HOST|PEOPLE_SERVICE_URL|CORS_ALLOWED_ORIGINS

Notes:
"Accounts and account-user mappings."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-002 story=US-001 acceptance=AC-002 flow=F1
- requirement=SYS-FR-006 story=US-003 acceptance=AC-004 flow=F3
- requirement=SYS-FR-008 story=US-005 acceptance=AC-006 flow=F5
- requirement=SYS-FR-009 story=US-006 acceptance=AC-007 flow=F6
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
- requirement=SYS-NFR-001 story=US-001 acceptance=AC-008 flow=F1
- requirement=SYS-NFR-005 story=US-009 acceptance=AC-009 flow=STARTUP
