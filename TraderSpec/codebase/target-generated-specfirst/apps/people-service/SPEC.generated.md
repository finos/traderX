# people-service

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/people-service-specfirst
- language: C#
- framework: ASP.NET Core
- buildTool: dotnet
- defaultPort: 18089
- dependsOn: none
- requiredEnv: PEOPLE_SERVICE_PORT|CORS_ALLOWED_ORIGINS

Notes:
"Directory lookups and person validation."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-009 story=US-006 acceptance=AC-007 flow=F6
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
- requirement=SYS-NFR-001 story=US-001 acceptance=AC-008 flow=F1
