# Level 2 - Containerized

## Objectives

- Capture local containerized execution as the bridge to platform concerns.
- Keep Docker-first workflows discoverable.

## Run

```bash
docker compose up -d
```

## Verify

```bash
./states/02-containerized/scripts/verify.sh
```

## Teardown

```bash
docker compose down
```

## What Changed vs Previous Level

- Adds container/orchestration orientation on top of service decomposition.
