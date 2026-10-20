import esbuild from "esbuild";

// Desk-side FDC3 client (estate-desk-client.ts) → ../fdc3-desk-client.js.
// Companion to build.mjs (the Desktop Agent): this bundle runs INSIDE the
// estate desk page (bankerx root) and connects the desk itself over WCP.
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