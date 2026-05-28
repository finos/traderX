# GHCR Run Bundle (012-platform-convergence-c3)

This convergence state does not use a compose runtime bundle. Use published images with the generated start script:

```bash
TRADERX_USE_PUBLISHED_IMAGES=1 \
TRADERX_PUBLISHED_NAMESPACE=traderx-c3 \
TRADERX_PUBLISHED_TAG=latest \
./scripts/start-state-012-platform-convergence-c3-generated.sh --skip-build
```

The start script will pull published images from `ghcr.io/finos/traderx-c3`, retag them to local expected names, and continue normal cluster startup.
