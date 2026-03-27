# reference-data

- kind: service
- sourcePath: reference-data
- language: TypeScript
- framework: NestJS
- buildTool: npm
- defaultPort: 18085
- dependsOn: database
- requiredEnv: none

Notes:
"Provides /stocks and /stocks/{ticker}."
