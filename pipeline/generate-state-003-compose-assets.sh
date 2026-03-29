#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/generated/code/target-generated"
SPEC_COMPOSE_PATH="${ROOT}/specs/003-containerized-compose-runtime/system/docker-compose.spec.yaml"
SPEC_EDGE_ROUTES_PATH="${ROOT}/specs/003-containerized-compose-runtime/system/edge-routing.json"
EDGE_COMPONENT_DIR="${ROOT}/generated/code/components/edge-proxy-specfirst"
EDGE_TARGET_DIR="${TARGET}/edge-proxy"
COMPOSE_DIR="${TARGET}/containerized-compose"

[[ -f "${SPEC_COMPOSE_PATH}" ]] || {
  echo "[fail] missing compose spec: ${SPEC_COMPOSE_PATH}"
  exit 1
}

[[ -f "${SPEC_EDGE_ROUTES_PATH}" ]] || {
  echo "[fail] missing edge routing spec: ${SPEC_EDGE_ROUTES_PATH}"
  exit 1
}

[[ -d "${EDGE_COMPONENT_DIR}" ]] || {
  echo "[fail] missing generated edge-proxy component: ${EDGE_COMPONENT_DIR}"
  exit 1
}

# Ensure target-generated is aligned with the latest generated components.
"${ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run >/dev/null

# Add edge-proxy component into target-generated for containerized state assets.
rm -rf "${EDGE_TARGET_DIR}"
cp -R "${EDGE_COMPONENT_DIR}" "${EDGE_TARGET_DIR}"
cp "${SPEC_EDGE_ROUTES_PATH}" "${EDGE_TARGET_DIR}/config/routes.json"

write_spring_boot_dockerfile() {
  local service_dir="$1"
  local port="$2"
  cat <<EOF > "${service_dir}/Dockerfile.compose"
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY . .
RUN chmod +x gradlew && ./gradlew --no-daemon clean bootJar \\
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
FROM eclipse-temurin:21-jdk
WORKDIR /app
COPY . .
RUN chmod +x gradlew run.sh && ./gradlew --no-daemon clean build
EXPOSE 18082 18083 18084
ENTRYPOINT ["./run.sh"]
EOF

cat <<'EOF' > "${TARGET}/reference-data/Dockerfile.compose"
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 18085
CMD ["npm", "run", "start"]
EOF

cat <<'EOF' > "${TARGET}/trade-feed/Dockerfile.compose"
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
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
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 18093
ENV WEB_SERVICE_PORT=18093
CMD ["npm", "run", "start"]
EOF

cat <<'EOF' > "${TARGET}/edge-proxy/Dockerfile.compose"
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 18080
ENV EDGE_PROXY_PORT=18080
CMD ["npm", "run", "start"]
EOF

mkdir -p "${COMPOSE_DIR}"
cp "${SPEC_COMPOSE_PATH}" "${COMPOSE_DIR}/docker-compose.yml"

cat <<EOF > "${COMPOSE_DIR}/README.md"
# State 003 Containerized Compose Runtime

Generated from:

- \`specs/003-containerized-compose-runtime/system/docker-compose.spec.yaml\`
- \`specs/003-containerized-compose-runtime/system/edge-routing.json\`

Run:

\`\`\`bash
docker compose -f docker-compose.yml up -d --build
\`\`\`
EOF

echo "[done] generated state 003 compose assets at ${COMPOSE_DIR}"
