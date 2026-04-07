# Internal Sanctioned Learning Graph

Only the states listed in `corporate/catalog/sanctioned-learning-graph.yaml` are approved for internal learning and runtime use.

```mermaid
flowchart LR
  S003["003 containerized compose"]
  S006["006 observability"]
  S008["008 order management"]
  C001["corp-001 managed postgres runtime"]
  C002["corp-002 internal docs branding"]

  S003 --> S006 --> S008 --> C001 --> C002
```

## Governance Notes

- This graph is intentionally narrower than public TraderX state lineage.
- Suppressed upstream states are omitted by policy.
- Internal-only states are explicitly marked with `corp-*` ids.
