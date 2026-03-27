---
title: Run Current Codebase From TraderSpec
---

# Run Current Codebase From TraderSpec

## Exact Current Stack (Recommended)

This uses the repository's canonical `docker-compose.yml` via TraderSpec wrappers.

```bash
./TraderSpec/codebase/scripts/run-current-codebase.sh
```

Stop:

```bash
./TraderSpec/codebase/scripts/stop-current-codebase.sh
```

## TraderSpec Parity Snapshot Mode

This runs from `TraderSpec/codebase/target-generated` after parity copy.

```bash
./TraderSpec/pipeline/generate-baseline-from-current.sh
./TraderSpec/codebase/scripts/run-parity-snapshot.sh
```

Stop:

```bash
./TraderSpec/codebase/scripts/stop-parity-snapshot.sh
```
