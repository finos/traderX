# web-front-end-angular

- kind: ui
- sourcePath: TraderSpec/codebase/generated-components/web-front-end-angular-specfirst
- language: TypeScript
- framework: Angular
- buildTool: npm
- defaultPort: 18093
- dependsOn: account-service|trade-service|position-service|reference-data|people-service|trade-feed|trade-processor
- requiredEnv: WEB_SERVICE_PORT

Notes:
"Primary UI for account/trade workflows with FINOS TraderX branding assets."

SpecKit Traceability:
- requirement=SYS-FR-001 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-NFR-003 story=US-007 acceptance=AC-001 flow=STARTUP
- requirement=SYS-NFR-006 story=US-001 acceptance=AC-009 flow=F2
