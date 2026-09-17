#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
while IFS= read -r module; do
  (
    cd "${module}"
    if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
    npm run build --if-present
    if [[ -f angular.json ]]; then
      npm test -- --watch=false --browsers=ChromeHeadlessNoSandbox
    else
      npm test --if-present
    fi
  )
done < <(jq -r '.modules.node[]' ci/state-metadata.json)
while IFS= read -r module; do
  (cd "${module}"; if [[ -f gradlew ]]; then bash ./gradlew clean build --no-daemon; else gradle clean build --no-daemon; fi)
done < <(jq -r '.modules.gradle[]' ci/state-metadata.json)
while IFS= read -r module; do
  (cd "${module}"; dotnet build --configuration Release; dotnet test --configuration Release --no-build)
done < <(jq -r '.modules.dotnet[]' ci/state-metadata.json)
