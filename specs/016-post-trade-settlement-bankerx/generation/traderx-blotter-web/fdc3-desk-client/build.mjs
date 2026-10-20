import esbuild from "esbuild";

// Desk-side FDC3 client (estate-desk-client.ts) → ../fdc3-desk-client.js.
// Companion to ../fdc3-agent/build.mjs (the Desktop Agent): this bundle runs
// INSIDE the estate desk page (bankerx root) and connects the desk itself
// over WCP. This package owns its node_modules on purpose — see package.json.
await esbuild.build({
  entryPoints: ["src/estate-desk-client.ts"],
  bundle: true,
  format: "iife",
  globalName: "__SynapticEstateDeskClient",
  outfile: "../fdc3-desk-client.js",
  target: "es2020",
  minify: true,
  sourcemap: false,
  legalComments: "inline",
  logLevel: "info",
});
console.log("Built ../fdc3-desk-client.js");