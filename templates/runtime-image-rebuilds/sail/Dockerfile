FROM @@BASE_IMAGE@@
RUN apk upgrade --no-cache && apk add --no-cache bash git python3 make g++ \
 && node -e 'const fs=require("fs"),p="/usr/local/lib/node_modules/npm/package.json",d=JSON.parse(fs.readFileSync(p)); delete d.devDependencies; fs.writeFileSync(p,JSON.stringify(d))' \
 && npm install --prefix /usr/local/lib/node_modules/npm --omit=dev --ignore-scripts --package-lock=false --no-audit --no-fund @@NPM_DEPENDENCIES@@ \
 && npm cache clean --force
