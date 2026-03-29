# Level 2 - Containerized

## Objectives

- Preserve containerization as a learning-path milestone specification.
- Keep baseline runtime independent from container infrastructure during SpecKit-first migration.

## Run

```bash
./scripts/start-base-uncontainerized-generated.sh
```

## Verify

```bash
./states/02-containerized/scripts/verify.sh
```

## Teardown

```bash
./scripts/stop-base-uncontainerized-generated.sh
```

## What Changed vs Previous Level

- Keeps container/orchestration progression as documented path artifacts while canonical runtime remains uncontainerized generated baseline.
