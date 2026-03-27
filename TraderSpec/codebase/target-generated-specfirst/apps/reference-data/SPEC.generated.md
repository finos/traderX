# reference-data

- kind: service
- sourcePath: TraderSpec/codebase/generated-components/reference-data-specfirst
- language: TypeScript
- framework: NestJS
- buildTool: npm
- defaultPort: 18085
- dependsOn: database
- requiredEnv: none

Notes:
"Provides /stocks and /stocks/{ticker}."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-FR-005 story=US-003 acceptance=AC-004 flow=F3
- requirement=SYS-FR-011 story=US-008 acceptance=AC-009 flow=STARTUP
- requirement=SYS-NFR-001 story=US-001 acceptance=AC-008 flow=F1
