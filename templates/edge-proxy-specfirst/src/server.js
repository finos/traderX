const fs = require('fs');
const path = require('path');
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function buildPathRewrite(prefix, rewritePrefix) {
  if (rewritePrefix === null || rewritePrefix === undefined) {
    return undefined;
  }

  const prefixRegex = new RegExp(`^${escapeRegex(prefix)}`);
  return (requestPath) => requestPath.replace(prefixRegex, rewritePrefix);
}

function loadRoutesConfig() {
  const configPath =
    process.env.EDGE_PROXY_ROUTES_FILE ||
    path.resolve(__dirname, '..', 'config', 'routes.json');

  const raw = fs.readFileSync(configPath, 'utf8');
  const config = JSON.parse(raw);

  if (!config.webTarget || !Array.isArray(config.apiRoutes)) {
    throw new Error(`invalid route config file: ${configPath}`);
  }

  return { configPath, config };
}

function createApp() {
  const app = express();
  const { configPath, config } = loadRoutesConfig();
  const port = Number(process.env.EDGE_PROXY_PORT || config.defaultPort || 18080);

  app.get('/health', (_req, res) => {
    res.json({
      status: 'ok',
      state: '002-edge-proxy-uncontainerized',
      routesFile: configPath
    });
  });

  for (const route of config.apiRoutes) {
    if (!route.prefix || !route.target) {
      throw new Error(`invalid api route entry in ${configPath}`);
    }

    app.use(
      route.prefix,
      createProxyMiddleware({
        target: route.target,
        changeOrigin: true,
        ws: Boolean(route.ws),
        pathRewrite: buildPathRewrite(route.prefix, route.rewritePrefix),
        logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn'
      })
    );
  }

  const webTarget = process.env.EDGE_PROXY_WEB_TARGET || config.webTarget;
  app.use(
    '/',
    createProxyMiddleware({
      target: webTarget,
      changeOrigin: true,
      ws: true,
      logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn'
    })
  );

  return { app, port };
}

const { app, port } = createApp();
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`[ready] edge-proxy listening on :${port}`);
});
