// v12 build — Angular-surface real-DA agent ONLY.
// Deliberately emits ../fdc3-agent-v12.js and NEVER ../fdc3-agent.js:
// the estate blotter pair (fdc3-agent.js + index.html) is FROZEN v11 bytes
// for the Oct 1 FINOS demo (md5 22533e09… / 5c17ea99…). v12 deploys to
// /var/www/traderx/angular/ only.
import esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/estate-agent.ts"],
  bundle: true,
  format: "iife",
  globalName: "__SynapticFDC3AgentModule",
  outfile: "../fdc3-agent-v12.js",
  target: "es2020",
  minify: true,
  sourcemap: false,
  legalComments: "inline",
  logLevel: "info",
});
console.log("Built ../fdc3-agent-v12.js (angular surface only)");