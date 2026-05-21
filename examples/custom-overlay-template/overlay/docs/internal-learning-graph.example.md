# Internal Sanctioned Learning Graph

Only the states listed in `overlay/catalog/sanctioned-learning-graph.example.yaml` are approved for internal learning and runtime use.

```mermaid
flowchart LR
  S004["004 containerized compose"]
  S007["007 observability"]
  S009["009 order management"]
  C001["custom-001 managed postgres runtime"]
  C002["custom-002 internal docs branding"]

  S004 --> S007 --> S009 --> C001 --> C002
```

## Governance Notes

- This graph is intentionally narrower than public TraderX state lineage.
- Suppressed upstream states are omitted by policy.
- Internal-only states are explicitly marked with `custom-*` ids.
