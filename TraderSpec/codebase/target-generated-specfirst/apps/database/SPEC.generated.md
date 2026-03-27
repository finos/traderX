# database

- kind: service
- sourcePath: database
- language: Java
- framework: H2 server + scripts
- buildTool: Gradle
- defaultPort: 18082
- dependsOn: none
- requiredEnv: DATABASE_WEB_HOSTNAMES

Notes:
"Hosts H2 DB runtime; exposes 18082/18083/18084."
