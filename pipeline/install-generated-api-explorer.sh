#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${GENERATED_ROOT}/code/target-generated}"
COMPONENTS_ROOT="${3:-${GENERATED_ROOT}/code/components}"
EXPLORER_ROOT="${TARGET_ROOT}/api-explorer"
CONTRACTS_ROOT="${EXPLORER_ROOT}/contracts"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/install-generated-api-explorer.sh <state-id> [target-root] [components-root]"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

mkdir -p "${CONTRACTS_ROOT}"

cat > "${EXPLORER_ROOT}/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>TraderX API Docs</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
    <style>
      body { margin: 0; background: #f5f7fb; }
      .topbar { background: #0b233a; color: #fff; padding: 12px 16px; font-family: sans-serif; }
      .topbar small { opacity: 0.8; }
      #swagger-ui { max-width: 1300px; margin: 0 auto; }
    </style>
  </head>
  <body>
    <div class="topbar">
      TraderX API Docs
      <small id="state-label"></small>
    </div>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    <script>
      function deriveRuntimeBasePath(service) {
        if (!service || !service.runtimeSpecPath) {
          return null;
        }

        const explicit = typeof service.runtimeBasePath === 'string' ? service.runtimeBasePath.trim() : '';
        if (explicit) {
          return explicit.startsWith('/') ? explicit : `/${explicit}`;
        }

        if (!service.runtimeSpecPath.startsWith('/')) {
          return null;
        }

        const segments = service.runtimeSpecPath.split('/').filter(Boolean);
        if (segments.length < 2) {
          return null;
        }
        return `/${segments[0]}`;
      }

      function resolveSpecKey(specUrl) {
        if (!specUrl || typeof specUrl !== 'string') {
          return null;
        }
        try {
          return new URL(specUrl, window.location.origin).toString();
        } catch (_error) {
          return null;
        }
      }

      function selectedSpecUrl(ui) {
        if (!ui || !ui.specSelectors || typeof ui.specSelectors.url !== 'function') {
          return null;
        }
        const raw = ui.specSelectors.url();
        if (!raw) {
          return null;
        }
        if (typeof raw === 'string') {
          return raw;
        }
        if (typeof raw.toJS === 'function') {
          return raw.toJS();
        }
        return String(raw);
      }

      async function bootstrap() {
        const response = await fetch('./catalog.json', { cache: 'no-cache' });
        if (!response.ok) {
          throw new Error('failed to load API catalog');
        }

        const catalog = await response.json();
        const services = Array.isArray(catalog.services) ? catalog.services : [];
        if (services.length === 0) {
          throw new Error('API catalog is empty');
        }

        const urls = services.map((service) => ({ name: service.name, url: service.specUrl }));
        const knownPrefixes = [];
        const serviceBySpec = new Map();
        for (const service of services) {
          const specKey = resolveSpecKey(service.specUrl);
          const runtimeBasePath = deriveRuntimeBasePath(service);
          if (runtimeBasePath) {
            knownPrefixes.push(runtimeBasePath);
          }
          if (specKey) {
            serviceBySpec.set(specKey, {
              ...service,
              runtimeBasePath,
            });
          }
        }

        const stateLabel = document.getElementById('state-label');
        if (stateLabel && catalog.stateId) {
          stateLabel.textContent = ` - state ${catalog.stateId}`;
        }

        window.ui = SwaggerUIBundle({
          dom_id: '#swagger-ui',
          urls,
          deepLinking: true,
          defaultModelsExpandDepth: -1,
          displayRequestDuration: true,
          docExpansion: 'list',
          filter: true,
          layout: 'StandaloneLayout',
          persistAuthorization: true,
          presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
          requestInterceptor: (request) => {
            if (!request || !request.url) {
              return request;
            }

            const activeSpec = selectedSpecUrl(window.ui);
            const activeSpecKey = resolveSpecKey(activeSpec);
            const service = activeSpecKey ? serviceBySpec.get(activeSpecKey) : null;
            if (!service || !service.runtimeBasePath) {
              return request;
            }

            let parsed;
            try {
              parsed = new URL(request.url, window.location.origin);
            } catch (_error) {
              return request;
            }

            const hasKnownPrefix = knownPrefixes.some((prefix) =>
              parsed.pathname === prefix || parsed.pathname.startsWith(`${prefix}/`));
            if (hasKnownPrefix) {
              return request;
            }

            const normalizedPath = parsed.pathname.startsWith('/') ? parsed.pathname : `/${parsed.pathname}`;
            parsed.pathname = `${service.runtimeBasePath}${normalizedPath}`.replace(/\/{2,}/g, '/');
            parsed.host = window.location.host;
            parsed.protocol = window.location.protocol;
            request.url = parsed.toString();
            return request;
          },
        });
      }

      bootstrap().catch((error) => {
        const el = document.getElementById('swagger-ui');
        if (!el) return;
        el.innerHTML = `<pre style="padding:16px;color:#a40000;">${String(error)}</pre>`;
      });
    </script>
  </body>
</html>
EOF

ROOT="${ROOT}" STATE_ID="${STATE_ID}" TARGET_ROOT="${TARGET_ROOT}" EXPLORER_ROOT="${EXPLORER_ROOT}" node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.ROOT;
const stateId = process.env.STATE_ID;
const targetRoot = process.env.TARGET_ROOT;
const explorerRoot = process.env.EXPLORER_ROOT;
const contractsRoot = path.join(explorerRoot, 'contracts');

const catalogPath = path.join(root, 'catalog', 'state-catalog.json');
const stateCatalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));

const defaults = {
  mountPath: '/api/docs',
  services: [
    {
      id: 'account-service',
      name: 'Account Service',
      detectPath: 'account-service',
      runtimeSpecPath: '/account-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/account-service/openapi.yaml',
    },
    {
      id: 'people-service',
      name: 'People Service',
      detectPath: 'people-service',
      runtimeSpecPath: '/people-service/swagger/v1/swagger.json',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/people-service/openapi.yaml',
    },
    {
      id: 'position-service',
      name: 'Position Service',
      detectPath: 'position-service',
      runtimeSpecPath: '/position-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/position-service/openapi.yaml',
    },
    {
      id: 'reference-data',
      name: 'Reference Data',
      detectPath: 'reference-data',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/reference-data/openapi.yaml',
    },
    {
      id: 'trade-processor',
      name: 'Trade Processor',
      detectPath: 'trade-processor',
      runtimeSpecPath: '/trade-processor/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/trade-processor/openapi.yaml',
    },
    {
      id: 'trade-service',
      name: 'Trade Service',
      detectPath: 'trade-service',
      runtimeSpecPath: '/trade-service/v3/api-docs',
      contractPath: 'specs/001-baseline-uncontainerized-parity/contracts/trade-service/openapi.yaml',
    },
    {
      id: 'order-matcher',
      name: 'Order Matcher',
      detectPath: 'order-matcher',
      runtimeSpecPath: '/order-matcher/v3/api-docs',
    },
  ],
};

const apiCatalog = stateCatalog.apiCatalog ?? defaults;
const mountPath = apiCatalog.mountPath ?? defaults.mountPath;
const serviceDefs = Array.isArray(apiCatalog.services) && apiCatalog.services.length > 0
  ? apiCatalog.services
  : defaults.services;

const deriveRuntimeBasePath = (def) => {
  if (typeof def.runtimeBasePath === 'string' && def.runtimeBasePath.trim()) {
    const explicit = def.runtimeBasePath.trim();
    return explicit.startsWith('/') ? explicit : `/${explicit}`;
  }
  const runtimeSpecPath = typeof def.runtimeSpecPath === 'string' ? def.runtimeSpecPath : '';
  if (!runtimeSpecPath.startsWith('/')) {
    return null;
  }
  const segments = runtimeSpecPath.split('/').filter(Boolean);
  if (segments.length < 2) {
    return null;
  }
  return `/${segments[0]}`;
};

const targetHas = (relativePath) =>
  fs.existsSync(path.join(targetRoot, relativePath));

const contracts = [];
const services = [];

for (const def of serviceDefs) {
  if (def.detectPath && !targetHas(def.detectPath)) {
    continue;
  }

  const contractName = `${def.id}-openapi.yaml`;
  const contractFile = def.contractPath ? path.join(root, def.contractPath) : null;
  const hasContract = Boolean(contractFile && fs.existsSync(contractFile));
  if (hasContract) {
    const outFile = path.join(contractsRoot, contractName);
    fs.copyFileSync(contractFile, outFile);
    contracts.push(contractName);
  }

  const contractUrl = hasContract ? `${mountPath}/contracts/${contractName}` : null;
  const runtimeSpecPath = def.runtimeSpecPath || null;
  const specUrl = runtimeSpecPath || contractUrl;
  if (!specUrl) {
    continue;
  }

  services.push({
    id: def.id,
    name: def.name || def.id,
    specUrl,
    runtimeSpecPath,
    runtimeBasePath: deriveRuntimeBasePath(def),
    contractUrl,
    interactive: Boolean(runtimeSpecPath),
  });
}

const runtimeCatalog = {
  generatedAtUtc: new Date().toISOString(),
  stateId,
  mountPath,
  services,
};

fs.writeFileSync(path.join(explorerRoot, 'catalog.json'), JSON.stringify(runtimeCatalog, null, 2) + '\n');
NODE

install_edge_proxy_explorer() {
  local edge_component="${COMPONENTS_ROOT}/edge-proxy-specfirst"
  local edge_server="${edge_component}/src/server.js"
  if [[ ! -f "${edge_server}" ]]; then
    return 0
  fi

  mkdir -p "${edge_component}/api-explorer"
  cp -R "${EXPLORER_ROOT}/." "${edge_component}/api-explorer/"

  cat > "${edge_server}" <<'EOF'
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
      state: process.env.EDGE_PROXY_STATE_ID || '002-edge-proxy-uncontainerized',
      routesFile: configPath,
    });
  });

  const apiExplorerDir = path.resolve(__dirname, '..', 'api-explorer');
  if (fs.existsSync(path.join(apiExplorerDir, 'index.html'))) {
    app.get('/api/docs', (_req, res) => {
      res.redirect('/api/docs/');
    });
    app.use('/api/docs', express.static(apiExplorerDir));
  }

  for (const route of config.apiRoutes) {
    if (!route.prefix || !route.target) {
      throw new Error(`invalid api route entry in ${configPath}`);
    }
    app.use(route.prefix, createProxyMiddleware({
      target: route.target,
      changeOrigin: true,
      ws: Boolean(route.ws),
      xfwd: true,
      pathRewrite: buildPathRewrite(route.prefix, route.rewritePrefix),
      logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn',
      on: {
        proxyReq: (proxyReq) => {
          proxyReq.setHeader('X-Forwarded-Prefix', route.prefix);
        },
      },
    }));
  }

  const webTarget = process.env.EDGE_PROXY_WEB_TARGET || config.webTarget;
  app.use('/', createProxyMiddleware({
    target: webTarget,
    changeOrigin: true,
    ws: true,
    xfwd: true,
    logLevel: process.env.EDGE_PROXY_LOG_LEVEL || 'warn',
  }));
  return { app, port };
}

const { app, port } = createApp();
app.listen(port, () => {
  console.log(`[ready] edge-proxy listening on :${port}`);
});
EOF

  echo "[ok] installed standalone API explorer into edge-proxy component"
}

ensure_compose_ingress_explorer() {
  local ingress_dir="${TARGET_ROOT}/ingress"
  local ingress_conf="${ingress_dir}/nginx.traderx.conf.template"
  local ingress_dockerfile="${ingress_dir}/Dockerfile.compose"

  if [[ ! -f "${ingress_conf}" ]]; then
    return 0
  fi

  mkdir -p "${ingress_dir}/api-explorer"
  cp -R "${EXPLORER_ROOT}/." "${ingress_dir}/api-explorer/"

  if [[ -f "${ingress_dockerfile}" ]] && ! rg -q 'COPY api-explorer/ /usr/share/nginx/html/api-docs/' "${ingress_dockerfile}"; then
    cat >> "${ingress_dockerfile}" <<'EOF'
COPY api-explorer/ /usr/share/nginx/html/api-docs/
EOF
  fi

  if ! rg -q 'location /api/docs/' "${ingress_conf}"; then
    local tmp_file
    tmp_file="$(mktemp)"
    awk '
      BEGIN {
        inserted = 0
      }
      {
        if (!inserted && $0 ~ /^[[:space:]]*location[[:space:]]+\/[[:space:]]*\{/) {
          print "    location = /api/docs {"
          print "        return 301 /api/docs/;"
          print "    }"
          print ""
          print "    location /api/docs/ {"
          print "        alias /usr/share/nginx/html/api-docs/;"
          print "        index index.html;"
          print "        try_files $uri $uri/ /api/docs/index.html;"
          print "    }"
          print ""
          inserted = 1
        }
        print
      }
    ' "${ingress_conf}" > "${tmp_file}"
    mv "${tmp_file}" "${ingress_conf}"
  fi

  echo "[ok] installed standalone API explorer into compose ingress"
}

ensure_kubernetes_explorer() {
  local base_dir="${TARGET_ROOT}/kubernetes-runtime/manifests/base"
  local edge_proxy_conf="${base_dir}/edge-proxy-configmap.yaml"
  local kustomization_file="${base_dir}/kustomization.yaml"
  local build_plan_file="${TARGET_ROOT}/kubernetes-runtime/build-plan.json"
  local explorer_image="traderx-api-explorer:local"

  if [[ ! -d "${base_dir}" || ! -f "${edge_proxy_conf}" || ! -f "${kustomization_file}" ]]; then
    return 0
  fi

  local cm_file="${base_dir}/api-explorer-configmap.yaml"
  local deploy_file="${base_dir}/api-explorer-deployment.yaml"
  local svc_file="${base_dir}/api-explorer-service.yaml"
  local explorer_dockerfile="${EXPLORER_ROOT}/Dockerfile"

  cat > "${explorer_dockerfile}" <<'EOF'
FROM nginx:1.27-alpine
COPY . /usr/share/nginx/html/api/docs/
EOF
  rm -f "${EXPLORER_ROOT}/.dockerignore"
  rm -f "${cm_file}"

  {
    echo "apiVersion: apps/v1"
    echo "kind: Deployment"
    echo "metadata:"
    echo "  name: api-explorer"
    echo "  namespace: traderx"
    echo "  labels:"
    echo "    app: api-explorer"
    echo "spec:"
    echo "  replicas: 1"
    echo "  selector:"
    echo "    matchLabels:"
    echo "      app: api-explorer"
    echo "  template:"
    echo "    metadata:"
    echo "      labels:"
    echo "        app: api-explorer"
    echo "    spec:"
    echo "      containers:"
    echo "        - name: api-explorer"
    echo "          image: ${explorer_image}"
    echo "          imagePullPolicy: IfNotPresent"
    echo "          ports:"
    echo "            - containerPort: 80"
    echo "              name: http"
  } > "${deploy_file}"

  cat > "${svc_file}" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: api-explorer
  namespace: traderx
  labels:
    app: api-explorer
spec:
  selector:
    app: api-explorer
  ports:
    - port: 8080
      targetPort: 80
      protocol: TCP
      name: http
EOF

  if ! rg -q 'location /api/docs/' "${edge_proxy_conf}"; then
    local tmp_file
    tmp_file="$(mktemp)"
    awk '
      BEGIN {
        inserted = 0
      }
      {
        if (!inserted && $0 ~ /^[[:space:]]*location[[:space:]]+\/[[:space:]]*\{/) {
          print "        location = /api/docs {"
          print "            return 301 /api/docs/;"
          print "        }"
          print "    "
          print "        location /api/docs/ {"
          print "            proxy_pass http://api-explorer:8080/api/docs/;"
          print "            proxy_http_version 1.1;"
          print "            proxy_set_header Host $http_host;"
          print "            proxy_set_header X-Forwarded-Proto $scheme;"
          print "            proxy_set_header X-Forwarded-Prefix /api/docs;"
          print "        }"
          print "    "
          inserted = 1
        }
        print
      }
    ' "${edge_proxy_conf}" > "${tmp_file}"
    mv "${tmp_file}" "${edge_proxy_conf}"
  fi

  if ! rg -q 'api-explorer-deployment.yaml' "${kustomization_file}"; then
    cat >> "${kustomization_file}" <<'EOF'
  - api-explorer-deployment.yaml
  - api-explorer-service.yaml
EOF
  fi
  perl -0pi -e 's#^\s*-\s*api-explorer-configmap\.yaml\s*\n##mg' "${kustomization_file}"

  if [[ -f "${build_plan_file}" ]]; then
    local tmp_plan
    tmp_plan="$(mktemp)"
    jq '
      .images = (
        (.images // [])
        | map(select(.name != "api-explorer"))
        + [{
          "name": "api-explorer",
          "image": "traderx-api-explorer:local",
          "context": "api-explorer",
          "dockerfile": "Dockerfile"
        }]
      )
      | .deployments = (
        (.deployments // [])
        | map(select(. != "api-explorer"))
        + ["api-explorer"]
      )
    ' "${build_plan_file}" > "${tmp_plan}"
    mv "${tmp_plan}" "${build_plan_file}"
  fi

  echo "[ok] installed standalone API explorer into Kubernetes manifests"
}

install_edge_proxy_explorer
ensure_compose_ingress_explorer
ensure_kubernetes_explorer

echo "[ok] installed standalone API explorer assets for ${STATE_ID}"
