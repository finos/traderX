/**
 * Builds ./fdc3-client.js (commit this artifact) from ./fdc3-client-entry.js.
 *
 * Build-time module resolution: @finos/fdc3-get-agent resolves against the
 * BankerX terminal's dependency tree (same 3.0.0-alpha.5 version pair as the
 * pack's @finos/fdc3-web-impl, and the desk-side binding the estate E2E gates
 * were proven on). Install it next to this dir, or point the alias below at a
 * local checkout:
 *
 *   cd specs/016-post-trade-settlement-bankerx/generation/mock-receiver
 *   npm install && node build-client.mjs
 */
import esbuild from "esbuild";

let entry = "./fdc3-client-entry.js";
try {
  await import("@finos/fdc3-get-agent/dist/src/index.js");
} catch {
  // Vendored/local override location, if the dependency was installed there.
  entry = undefined;
}

await esbuild.build({
  entryPoints: [entry ?? "./fdc3-client-entry.js"],
  bundle: true,
  format: "iife",
  outfile: "./fdc3-client.js",
  target: "es2020",
  minify: true,
  sourcemap: false,
  legalComments: "inline",
  logLevel: "info",
  alias: entry ? undefined : undefined,
});
console.log("Built ./fdc3-client.js");