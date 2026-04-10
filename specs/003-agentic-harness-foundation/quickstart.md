# Quickstart: Agentic Harness Foundation

## 1) Generate This State

```bash
bash pipeline/generate-state.sh 003-agentic-harness-foundation
```

## 2) Start Runtime

```bash
./scripts/start-state-003-agentic-harness-foundation-generated.sh
```

## 3) Run Smoke Tests

```bash
./scripts/test-state-003-agentic-harness-foundation.sh
```

## 4) Stop Runtime

```bash
./scripts/stop-state-003-agentic-harness-foundation-generated.sh
```

## 5) Inspect Harness Files

```bash
ls -1 generated/code/target-generated/AGENTS.md \
      generated/code/target-generated/ARCHITECTURE.md \
      generated/code/target-generated/CONTRIBUTING.md
```
