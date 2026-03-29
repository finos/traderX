#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="005-radius-kubernetes-platform"
PARENT_STATE_ID="004-kubernetes-runtime"
TARGET_ROOT="${ROOT}/generated/code/target-generated"
STATE_OUT="${TARGET_ROOT}/radius-kubernetes-platform"
PARENT_OUT="${TARGET_ROOT}/kubernetes-runtime"
PARENT_BUILD_PLAN="${PARENT_OUT}/build-plan.json"

require_image() {
  local name="$1"
  local image
  image="$(jq -r --arg name "${name}" '.images[] | select(.name == $name) | .image' "${PARENT_BUILD_PLAN}")"
  if [[ -z "${image}" || "${image}" == "null" ]]; then
    echo "[fail] missing image mapping in ${PARENT_BUILD_PLAN} for component: ${name}"
    exit 1
  fi
  printf "%s" "${image}"
}

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq command is required"
  exit 1
fi

# Build on top of state 004 assets and image build plan.
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"

[[ -f "${PARENT_BUILD_PLAN}" ]] || {
  echo "[fail] missing parent build plan: ${PARENT_BUILD_PLAN}"
  exit 1
}

database_image="$(require_image "database")"
reference_data_image="$(require_image "reference-data")"
trade_feed_image="$(require_image "trade-feed")"
people_service_image="$(require_image "people-service")"
account_service_image="$(require_image "account-service")"
position_service_image="$(require_image "position-service")"
trade_processor_image="$(require_image "trade-processor")"
trade_service_image="$(require_image "trade-service")"
web_front_end_image="$(require_image "web-front-end-angular")"
edge_proxy_image="$(jq -r '.runtime.edge.image // empty' "${ROOT}/specs/004-kubernetes-runtime/system/kubernetes-runtime.spec.json")"

if [[ -z "${edge_proxy_image}" ]]; then
  echo "[fail] missing runtime edge image in specs/004-kubernetes-runtime/system/kubernetes-runtime.spec.json"
  exit 1
fi

rm -rf "${STATE_OUT}"
mkdir -p "${STATE_OUT}/radius/.rad" "${STATE_OUT}/spec-source"

cat > "${STATE_OUT}/radius/app.bicep" <<EOF
extension radius

param application string = 'traderx-state-005'

resource database 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'database'
  properties: {
    application: application
    container: {
      image: '${database_image}'
      ports: {
        tcp: { containerPort: 18082 }
        pg: { containerPort: 18083 }
        web: { containerPort: 18084 }
      }
    }
  }
}

resource referencedata 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'reference-data'
  properties: {
    application: application
    container: {
      image: '${reference_data_image}'
      ports: {
        web: { containerPort: 18085 }
      }
    }
  }
}

resource tradefeed 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-feed'
  properties: {
    application: application
    container: {
      image: '${trade_feed_image}'
      ports: {
        web: { containerPort: 18086 }
      }
    }
  }
}

resource peopleservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'people-service'
  properties: {
    application: application
    container: {
      image: '${people_service_image}'
      ports: {
        web: { containerPort: 18089 }
      }
    }
  }
}

resource accountservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'account-service'
  properties: {
    application: application
    container: {
      image: '${account_service_image}'
      ports: {
        web: { containerPort: 18088 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        PEOPLE_SERVICE_HOST: { value: peopleservice.name }
      }
    }
    connections: {
      peopleservice: { source: peopleservice.id }
      database: { source: database.id }
    }
  }
}

resource positionservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'position-service'
  properties: {
    application: application
    container: {
      image: '${position_service_image}'
      ports: {
        web: { containerPort: 18090 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
      }
    }
    connections: {
      database: { source: database.id }
    }
  }
}

resource tradeservice 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-service'
  properties: {
    application: application
    container: {
      image: '${trade_service_image}'
      ports: {
        web: { containerPort: 18092 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        PEOPLE_SERVICE_HOST: { value: peopleservice.name }
        ACCOUNT_SERVICE_HOST: { value: accountservice.name }
        REFERENCE_DATA_HOST: { value: referencedata.name }
        TRADE_FEED_HOST: { value: tradefeed.name }
      }
    }
    connections: {
      database: { source: database.id }
      peopleservice: { source: peopleservice.id }
      accountservice: { source: accountservice.id }
      referencedata: { source: referencedata.id }
      tradefeed: { source: tradefeed.id }
    }
  }
}

resource tradeprocessor 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'trade-processor'
  properties: {
    application: application
    container: {
      image: '${trade_processor_image}'
      ports: {
        web: { containerPort: 18091 }
      }
      env: {
        DATABASE_TCP_HOST: { value: database.name }
        TRADE_FEED_HOST: { value: tradefeed.name }
      }
    }
    connections: {
      database: { source: database.id }
      tradefeed: { source: tradefeed.id }
    }
  }
}

resource webfrontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web-front-end-angular'
  properties: {
    application: application
    container: {
      image: '${web_front_end_image}'
      ports: {
        web: { containerPort: 18093 }
      }
    }
    connections: {
      tradefeed: { source: tradefeed.id }
      accountservice: { source: accountservice.id }
      positionservice: { source: positionservice.id }
      tradeservice: { source: tradeservice.id }
      referencedata: { source: referencedata.id }
    }
  }
}

resource edgeproxy 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'edge-proxy'
  properties: {
    application: application
    container: {
      image: '${edge_proxy_image}'
      ports: {
        web: { containerPort: 8080 }
      }
    }
    connections: {
      database: { source: database.id }
      tradefeed: { source: tradefeed.id }
      peopleservice: { source: peopleservice.id }
      accountservice: { source: accountservice.id }
      positionservice: { source: positionservice.id }
      tradeservice: { source: tradeservice.id }
      tradeprocessor: { source: tradeprocessor.id }
      webfrontend: { source: webfrontend.id }
      referencedata: { source: referencedata.id }
    }
  }
}
EOF

cat > "${STATE_OUT}/radius/bicepconfig.json" <<'EOF'
{
  "experimentalFeaturesEnabled": {
    "extensibility": true,
    "extensionRegistry": true,
    "dynamicTypeLoading": true
  },
  "extensions": {
    "radius": "br:biceptypes.azurecr.io/radius:0.38",
    "aws": "br:biceptypes.azurecr.io/aws:0.38"
  }
}
EOF

cat > "${STATE_OUT}/radius/.rad/rad.yaml" <<'EOF'
workspace:
  application: "traderx-state-005"
EOF

cp "${ROOT}/specs/005-radius-kubernetes-platform/spec.md" "${STATE_OUT}/spec-source/spec.md"
cp "${ROOT}/specs/005-radius-kubernetes-platform/requirements/functional-delta.md" "${STATE_OUT}/spec-source/functional-delta.md"
cp "${ROOT}/specs/005-radius-kubernetes-platform/requirements/nonfunctional-delta.md" "${STATE_OUT}/spec-source/nonfunctional-delta.md"
cp "${ROOT}/specs/005-radius-kubernetes-platform/contracts/contract-delta.md" "${STATE_OUT}/spec-source/contract-delta.md"
cp "${PARENT_BUILD_PLAN}" "${STATE_OUT}/upstream-build-plan.json"

cat > "${STATE_OUT}/README.md" <<'EOF'
# State 005 Radius Platform Artifacts

Generated from:

- `specs/005-radius-kubernetes-platform/**`
- `generated/code/target-generated/kubernetes-runtime/build-plan.json`

State intent:

- preserve state 004 runtime behavior,
- add Radius app/resource definitions as the primary platform abstraction artifacts.

Artifacts:

- Radius app model: `radius/app.bicep`
- Radius workspace config: `radius/.rad/rad.yaml`
- Bicep extension config: `radius/bicepconfig.json`
- Parent image map reference: `upstream-build-plan.json`

Run baseline runtime for this state:

```bash
./scripts/start-state-005-radius-kubernetes-platform-generated.sh --provider kind
```

Run state smoke tests:

```bash
./scripts/test-state-005-radius-kubernetes-platform.sh
```

Optional Radius command flow (requires `rad`):

```bash
cd generated/code/target-generated/radius-kubernetes-platform/radius
rad run app.bicep
```
EOF

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<EOF
[summary] state=${STATE_ID}
[summary] parent-state=${PARENT_STATE_ID}
[summary] impacted-assets=radius-app-model,radius-workspace,bicep-extension-config
[summary] generated-path=generated/code/target-generated/radius-kubernetes-platform
[summary] runtime-entrypoint=./scripts/start-state-005-radius-kubernetes-platform-generated.sh
EOF
