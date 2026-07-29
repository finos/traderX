# GHCR Run Bundle (012-platform-convergence-c3)

This convergence state does not use a compose runtime bundle. Use published images with the generated start script:

```bash
TRADERX_SKIP_GENERATE=1 \
TRADERX_USE_PUBLISHED_IMAGES=1 \
TRADERX_PUBLISHED_NAMESPACE=traderx-c3 \
TRADERX_PUBLISHED_TAG=latest \
./scripts/start-state-012-platform-convergence-c3-generated.sh --skip-build
```

The generated snapshot already contains runtime artifacts, so `TRADERX_SKIP_GENERATE=1` keeps this flow independent from source-generation scripts that are not shipped in generated bundle roots.
The start script will pull published images from `ghcr.io/finos/traderx-c3`, retag them to local expected names, and continue normal cluster startup.
