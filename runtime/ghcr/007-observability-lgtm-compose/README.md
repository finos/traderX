# GHCR Run Bundle (007-observability-lgtm-compose)

Run this state directly from published GHCR images.

1. Optionally set a specific tag:

```bash
export TRADERX_IMAGE_TAG=latest
```

2. Pull and start:

```bash
docker compose -f runtime/ghcr/007-observability-lgtm-compose/docker-compose.ghcr.yml pull
docker compose -f runtime/ghcr/007-observability-lgtm-compose/docker-compose.ghcr.yml up -d
```

3. Stop:

```bash
docker compose -f runtime/ghcr/007-observability-lgtm-compose/docker-compose.ghcr.yml down
```

This bundle overlays `observability-lgtm-compose/docker-compose.yml` and replaces buildable app services with GHCR images under `ghcr.io/finos/traderx-c1`.
