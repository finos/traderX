# account-service

- kind: service
- sourcePath: account-service
- language: Java
- framework: Spring Boot
- buildTool: Gradle
- defaultPort: 18088
- dependsOn: database|people-service
- requiredEnv: DATABASE_TCP_HOST|PEOPLE_SERVICE_HOST

Notes:
"Accounts and account-user mappings."
