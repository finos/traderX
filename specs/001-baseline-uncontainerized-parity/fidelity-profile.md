# Baseline Fidelity Profile

This profile captures the technical implementation shape that generation should preserve for baseline parity.

## Component Stack Profile

| Component | Language | Framework | Build Tool | Default Port | Contract |
|---|---|---|---|---:|---|
| database | Java | H2 server + scripts | Gradle | 18082 | none |
| reference-data | TypeScript | NestJS | npm | 18085 | `contracts/reference-data/openapi.yaml` |
| trade-feed | JavaScript | Node + Socket.IO | npm | 18086 | none |
| people-service | C# | ASP.NET Core | dotnet | 18089 | `contracts/people-service/openapi.yaml` |
| account-service | Java | Spring Boot | Gradle | 18088 | `contracts/account-service/openapi.yaml` |
| position-service | Java | Spring Boot | Gradle | 18090 | `contracts/position-service/openapi.yaml` |
| trade-processor | Java | Spring Boot | Gradle | 18091 | `contracts/trade-processor/openapi.yaml` |
| trade-service | Java | Spring Boot | Gradle | 18092 | `contracts/trade-service/openapi.yaml` |
| web-front-end-angular | TypeScript | Angular | npm | 18093 | none |

## Runtime Dependency and Env Fidelity

Generation must preserve:

- startup order: `database -> reference-data -> trade-feed -> people-service -> account-service -> position-service -> trade-processor -> trade-service -> web-front-end-angular`
- required env wiring from component manifests (ports, service hosts/urls, database credentials, feed endpoints)
- CORS allowlist behavior for pre-ingress browser calls

## Closeness Validation Policy

Use semantic compare harness:

```bash
bash TraderSpec/pipeline/speckit/compare-all-component-generation.sh HEAD --allow-differences
```

Expected result policy:

- blocked categories: `source-code`, `runtime-config`, `api-contract`
- conditional categories: `build-tooling`, `deployment-runtime`, `seed-data`, `branding-assets`
- allowed categories by default: `docs-spec` only

Any blocked-category difference requires either:

1. spec + plan + tasks updates that justify the change, and
2. updated acceptance evidence proving compatibility intent.
