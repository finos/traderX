# Component Technical Catalog

This is the browsable view of `component-spec.csv`.

| Component | Kind | Language/Framework | Port | Contract |
|---|---|---|---|---|
| database | service | Java / H2 scripts | 18082 | none |
| reference-data | service | TypeScript / NestJS | 18085 | `reference-data/openapi.yaml` |
| trade-feed | service | JavaScript / Socket.IO | 18086 | none |
| people-service | service | C# / ASP.NET Core | 18089 | `people-service/openapi.yaml` |
| account-service | service | Java / Spring Boot | 18088 | `account-service/openapi.yaml` |
| position-service | service | Java / Spring Boot | 18090 | `position-service/openapi.yaml` |
| trade-service | service | Java / Spring Boot | 18092 | `trade-service/openapi.yaml` |
| trade-processor | service | Java / Spring Boot | 18091 | `trade-processor/openapi.yaml` |
| web-front-end-angular | ui | TypeScript / Angular | 18093 | none |

## Source of Truth

- `TraderSpec/catalog/component-spec.csv`
