# GHCR Run Bundle (009-order-management-matcher)

Run this state directly from published GHCR images.

1. Optionally set a specific tag:

```bash
export TRADERX_IMAGE_TAG=latest
```

2. Pull and start:

```bash
docker compose -f runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml pull
docker compose -f runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml up -d
```

3. Stop:

```bash
docker compose -f runtime/ghcr/009-order-management-matcher/docker-compose.ghcr.yml down
```

This bundle overlays `order-management-matcher/docker-compose.yml` and replaces buildable app services with GHCR images under `ghcr.io/finos/traderx-c2`.
