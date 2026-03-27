# database

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/database-specfirst
- language: Java
- framework: H2 server + scripts
- buildTool: Gradle
- defaultPort: 18082
- dependsOn: none
- requiredEnv: DATABASE_WEB_HOSTNAMES

Notes:
"Hosts H2 DB runtime; exposes 18082/18083/18084."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-007 story=US-004 acceptance=AC-005 flow=F4
- requirement=SYS-NFR-002 story=US-007 acceptance=AC-001 flow=STARTUP
