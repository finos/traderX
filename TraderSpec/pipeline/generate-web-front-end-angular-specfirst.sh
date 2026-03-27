#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${ROOT}/templates/web-front-end/angular"
TARGET="${ROOT}/codebase/generated-components/web-front-end-angular-specfirst"

if [[ ! -d "${SOURCE}" ]]; then
  echo "[error] missing source Angular workspace: ${SOURCE}"
  exit 1
fi

rm -rf "${TARGET}"
mkdir -p "${TARGET}/main"

cp "${SOURCE}/package.json" "${TARGET}/package.json"
cp "${SOURCE}/angular.json" "${TARGET}/angular.json"
cp "${SOURCE}/README.md" "${TARGET}/README.md"
cp "${SOURCE}/Dockerfile" "${TARGET}/Dockerfile"
cp "${SOURCE}/Dockerfile.prod" "${TARGET}/Dockerfile.prod"
cp "${SOURCE}/karma.conf.js" "${TARGET}/karma.conf.js"
cp "${SOURCE}/prettier.config.js" "${TARGET}/prettier.config.js"
cp "${SOURCE}/tsconfig.json" "${TARGET}/tsconfig.json"
cp "${SOURCE}/tsconfig.app.json" "${TARGET}/tsconfig.app.json"
cp "${SOURCE}/tsconfig.spec.json" "${TARGET}/tsconfig.spec.json"

cp -R "${SOURCE}/main/app" "${TARGET}/main/app"
cp -R "${SOURCE}/main/assets" "${TARGET}/main/assets"
cp -R "${SOURCE}/main/environments" "${TARGET}/main/environments"
cp "${SOURCE}/main/index.html" "${TARGET}/main/index.html"
cp "${SOURCE}/main/main.ts" "${TARGET}/main/main.ts"
cp "${SOURCE}/main/polyfills.ts" "${TARGET}/main/polyfills.ts"
cp "${SOURCE}/main/styles.scss" "${TARGET}/main/styles.scss"
cp "${SOURCE}/main/test.ts" "${TARGET}/main/test.ts"
cp "${SOURCE}/main/tslint.json" "${TARGET}/main/tslint.json"

for asset in \
  "main/assets/img/traderx-apple-touch-icon.png" \
  "main/assets/img/traderx-icon.png" \
  "main/assets/img/FINOS_Icon_White.png"; do
  if [[ ! -f "${TARGET}/${asset}" ]]; then
    echo "[error] missing required branding asset after generation: ${asset}"
    exit 1
  fi
done

cat <<'EOF' > "${TARGET}/SPEC.generated.md"
# Web Front End Angular (Spec-First Generated)

This generated component preserves baseline TraderX branding and logo assets:

- `main/assets/img/traderx-apple-touch-icon.png`
- `main/assets/img/traderx-icon.png`
- `main/assets/img/FINOS_Icon_White.png`

Runtime is still `npm run start` on port `18093` by default.
EOF

echo "[done] regenerated ${TARGET}"
