# ingress

- kind: edge
- sourcePath: ingress
- language: Nginx
- framework: Nginx
- buildTool: Docker build
- defaultPort: 8080
- dependsOn: web-front-end-angular|trade-service|account-service|position-service|people-service|trade-feed
- requiredEnv: TRADERX_FQDN

Notes:
"Edge routing for browser access."
