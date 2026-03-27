# Conformance Packs

Conformance packs are per-component gate definitions generated from the Spec Kit traceability matrix.

Each pack captures:

- mapped user stories
- mapped FR and NFR requirement IDs
- mapped acceptance criteria IDs
- mapped flows
- contract validation references
- verification command/file references

Sync packs:

```bash
bash TraderSpec/pipeline/speckit/sync-conformance-packs.sh
```

Run all pack gates:

```bash
bash TraderSpec/pipeline/speckit/run-all-conformance-packs.sh
```

Run a single component pack:

```bash
bash TraderSpec/pipeline/speckit/run-component-conformance-pack.sh trade-service
```
