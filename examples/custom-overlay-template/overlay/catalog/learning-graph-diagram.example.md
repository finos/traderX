# Overlay Learning Graph Diagram Example

Copy this into your overlay repository `docs/learning/index.md` and replace IDs, labels, and links with your sanctioned states.

```mermaid
flowchart TB
  U001["U001: Baseline Parity"]
  U002["U002: Edge Proxy"]
  CORP000["CORP-000: Overlay Baseline\n(anchor)"]
  CORP001["CORP-001: Corporate Runtime\n(runnable)"]
  CORP002["CORP-002: Custom Messaging\n(feature)"]

  U001 --> U002
  U001 --> CORP000
  CORP000 --> CORP001
  CORP001 --> CORP002
  U002 -.->|converges| CORP002

  %% Replace placeholder links with your actual public FINOS and internal overlay doc URLs.
  click U001 "https://finos.github.io/traderX/docs/learning/001-baseline-uncontainerized-parity" "FINOS U001 learning guide"
  click U002 "https://finos.github.io/traderX/docs/learning/002-edge-proxy-uncontainerized" "FINOS U002 learning guide"
  click CORP000 "/docs/learning/corp-000-overlay-baseline" "Overlay CORP-000 learning guide"
  click CORP001 "/docs/learning/corp-001-corporate-runtime" "Overlay CORP-001 learning guide"
  click CORP002 "/docs/learning/corp-002-custom-messaging" "Overlay CORP-002 learning guide"

  classDef upstream fill:#fff8e1,stroke:#f57f17,stroke-width:1px,stroke-dasharray:5 5
  classDef anchor fill:#eceff1,stroke:#455a64,stroke-width:1px
  classDef runnable fill:#e3f2fd,stroke:#1565c0,stroke-width:1px
  classDef feature fill:#e8f5e9,stroke:#2e7d32,stroke-width:1px

  class U001,U002 upstream
  class CORP000 anchor
  class CORP001 runnable
  class CORP002 feature
```

## State-to-Artifact Table Template

| State | Learning Guide | Spec Pack | Generated Branch | Diff vs Previous | Runnable |
|---|---|---|---|---|---|
| U001 | [U001 Guide](https://finos.github.io/traderX/docs/learning/001-baseline-uncontainerized-parity) | `specs/001-baseline-uncontainerized-parity` | `code/generated-state-001-baseline-uncontainerized-parity` | N/A | No |
| U002 | [U002 Guide](https://finos.github.io/traderX/docs/learning/002-edge-proxy-uncontainerized) | `specs/002-edge-proxy-uncontainerized` | `code/generated-state-002-edge-proxy-uncontainerized` | [Compare](https://github.com/finos/traderX/compare/code/generated-state-001-baseline-uncontainerized-parity...code/generated-state-002-edge-proxy-uncontainerized) | No |
| CORP-000 | [CORP-000 Guide](/docs/learning/corp-000-overlay-baseline) | `specs/corp-000-overlay-baseline` | `code/generated-state-corp-000-overlay-baseline` | [Compare](https://github.example.com/org/traderx-overlay/compare/code/generated-state-002-edge-proxy-uncontainerized...code/generated-state-corp-000-overlay-baseline) | No |
| CORP-001 | [CORP-001 Guide](/docs/learning/corp-001-corporate-runtime) | `specs/corp-001-corporate-runtime` | `code/generated-state-corp-001-corporate-runtime` | [Compare](https://github.example.com/org/traderx-overlay/compare/code/generated-state-corp-000-overlay-baseline...code/generated-state-corp-001-corporate-runtime) | Yes |
| CORP-002 | [CORP-002 Guide](/docs/learning/corp-002-custom-messaging) | `specs/corp-002-custom-messaging` | `code/generated-state-corp-002-custom-messaging` | [Compare](https://github.example.com/org/traderx-overlay/compare/code/generated-state-corp-001-corporate-runtime...code/generated-state-corp-002-custom-messaging) | Yes |
