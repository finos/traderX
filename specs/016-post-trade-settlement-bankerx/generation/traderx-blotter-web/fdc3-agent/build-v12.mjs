// v12 build — Angular-surface real-DA agent ONLY.
// Deliberately emits ../fdc3-agent-v12.js and NEVER ../fdc3-agent.js:
// Estate unfroze 2026-09-30 by operator directive; v12+ deploys to BOTH
// /var/www/traderx/ and /var/www/traderx/angular/ (same bytes, ?v bump).
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