# GHCR Run Bundle (004-containerized-compose-runtime)

Run this state directly from published GHCR images.

1. Optionally set a specific tag:

```bash
export TRADERX_IMAGE_TAG=latest
```

2. Pull and start:

```bash
docker compose -f runtime/ghcr/004-containerized-compose-runtime/docker-compose.ghcr.yml pull
docker compose -f runtime/ghcr/004-containerized-compose-runtime/docker-compose.ghcr.yml up -d
```

3. Stop:

```bash
docker compose -f runtime/ghcr/004-containerized-compose-runtime/docker-compose.ghcr.yml down
```

This bundle overlays `containerized-compose/docker-compose.yml` and replaces buildable app services with GHCR images under `ghcr.io/finos/traderx-c0`.
