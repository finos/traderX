#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/generated/code/target-generated"
SPEC_COMPOSE_PATH="${ROOT}/specs/003-containerized-compose-runtime/system/docker-compose.spec.yaml"
SPEC_INGRESS_TEMPLATE_PATH="${ROOT}/specs/003-containerized-compose-runtime/system/ingress-nginx.conf.template"
INGRESS_TARGET_DIR="${TARGET}/ingress"
COMPOSE_DIR="${TARGET}/containerized-compose"

[[ -f "${SPEC_COMPOSE_PATH}" ]] || {
  echo "[fail] missing compose spec: ${SPEC_COMPOSE_PATH}"
  exit 1
}

[[ -f "${SPEC_INGRESS_TEMPLATE_PATH}" ]] || {
  echo "[fail] missing nginx ingress template spec: ${SPEC_INGRESS_TEMPLATE_PATH}"
  exit 1
}

# Ensure target-generated is aligned with the latest generated components.
"${ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run >/dev/null

# Add ingress component for containerized state assets.
rm -rf "${INGRESS_TARGET_DIR}"
mkdir -p "${INGRESS_TARGET_DIR}"
cp "${SPEC_INGRESS_TEMPLATE_PATH}" "${INGRESS_TARGET_DIR}/nginx.traderx.conf.template"

write_spring_boot_dockerfile() {
  local service_dir="$1"
  local port="$2"
  cat <<EOF > "${service_dir}/Dockerfile.compose"
# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.gradle,sharing=locked \\
    chmod +x gradlew && ./gradlew --no-daemon clean bootJar \\
 && jar_path="\$(ls -1 build/libs/*.jar | grep -v -- '-plain\\.jar$' | head -n 1)" \\
 && cp "\${jar_path}" build/libs/app.jar

FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY --from=build /app/build/libs/app.jar app.jar
EXPOSE ${port}
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
EOF
}

cat <<'EOF' > "${TARGET}/database/Dockerfile.compose"
# syntax=docker/dockerfile:1.7
FROM eclipse-temurin:21-jdk
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.gradle,sharing=locked \
    chmod +x gradlew run.sh && ./gradlew --no-daemon clean build
EXPOSE 18082 18083 18084
ENTRYPOINT ["./run.sh"]
EOF

cat <<'EOF' > "${TARGET}/reference-data/Dockerfile.compose"
# syntax=docker/dockerfile:1.7
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    if [ -f package-lock.json ]; then \
      npm ci --no-audit --prefer-offline; \
    else \
      npm install --no-audit --prefer-offline; \
    fi
COPY . .
EXPOSE 18085
CMD ["npm", "run", "start"]
EOF

cat <<'EOF' > "${TARGET}/trade-feed/Dockerfile.compose"
# syntax=docker/dockerfile:1.7
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    if [ -f package-lock.json ]; then \
      npm ci --no-audit --prefer-offline; \
    else \
      npm install --no-audit --prefer-offline; \
    fi
COPY . .
EXPOSE 18086
CMD ["npm", "run", "start"]
EOF

cat <<'EOF' > "${TARGET}/people-service/Dockerfile.compose"
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
WORKDIR /src/PeopleService.WebApi
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 18089
ENV PEOPLE_SERVICE_PORT=18089
ENTRYPOINT ["dotnet", "PeopleService.WebApi.dll"]
EOF

write_spring_boot_dockerfile "${TARGET}/account-service" "18088"
write_spring_boot_dockerfile "${TARGET}/position-service" "18090"
write_spring_boot_dockerfile "${TARGET}/trade-processor" "18091"
write_spring_boot_dockerfile "${TARGET}/trade-service" "18092"

cat <<'EOF' > "${TARGET}/web-front-end/angular/Dockerfile.compose"
# syntax=docker/dockerfile:1.7
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    if [ -f package-lock.json ]; then \
      npm ci --no-audit --prefer-offline; \
    else \
      npm install --no-audit --prefer-offline; \
    fi
COPY . .
EXPOSE 18093
ENV WEB_SERVICE_PORT=18093
CMD ["npm", "run", "start"]
EOF

cat <<'EOF' > "${TARGET}/ingress/Dockerfile.compose"
FROM nginx:alpine-slim
EXPOSE 8080

ARG NGINX_HOST="localhost"
ENV NGINX_HOST=${NGINX_HOST}

ARG DATABASE_URL="http://database:18084/"
ENV DATABASE_URL=${DATABASE_URL}

ARG TRADE_PROCESSOR_URL="http://trade-processor:18091/"
ENV TRADE_PROCESSOR_URL=${TRADE_PROCESSOR_URL}

ARG ACCOUNT_SERVICE_URL="http://account-service:18088/"
ENV ACCOUNT_SERVICE_URL=${ACCOUNT_SERVICE_URL}

ARG PEOPLE_SERVICE_URL="http://people-service:18089/"
ENV PEOPLE_SERVICE_URL=${PEOPLE_SERVICE_URL}

ARG POSITION_SERVICE_URL="http://position-service:18090/"
ENV POSITION_SERVICE_URL=${POSITION_SERVICE_URL}

ARG REFERENCE_DATA_URL="http://reference-data:18085/"
ENV REFERENCE_DATA_URL=${REFERENCE_DATA_URL}

ARG TRADE_FEED_URL="http://trade-feed:18086/"
ENV TRADE_FEED_URL=${TRADE_FEED_URL}

ARG WEB_FRONTEND_URL="http://web-front-end-angular:18093/"
ENV WEB_FRONTEND_URL=${WEB_FRONTEND_URL}

ARG TRADE_SERVICE_URL="http://trade-service:18092/"
ENV TRADE_SERVICE_URL=${TRADE_SERVICE_URL}

COPY nginx.traderx.conf.template /etc/nginx/templates/default.conf.template
EOF

mkdir -p "${COMPOSE_DIR}"
cp "${SPEC_COMPOSE_PATH}" "${COMPOSE_DIR}/docker-compose.yml"

cat <<EOF > "${COMPOSE_DIR}/README.md"
# State 003 Containerized Compose Runtime

Generated from:

- \`specs/003-containerized-compose-runtime/system/docker-compose.spec.yaml\`
- \`specs/003-containerized-compose-runtime/system/ingress-nginx.conf.template\`

Run:

\`\`\`bash
docker compose -f docker-compose.yml up -d --build
\`\`\`

Ingress UI:

- \`http://localhost:8080\`
EOF

echo "[done] generated state 003 compose assets at ${COMPOSE_DIR}"
