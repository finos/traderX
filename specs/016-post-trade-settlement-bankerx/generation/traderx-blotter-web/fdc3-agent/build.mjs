import esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/estate-agent.ts"],
  bundle: true,
  format: "iife",
  globalName: "__SynapticFDC3AgentModule",
  outfile: "../fdc3-agent.js",
  target: "es2020",
  minify: true,
  sourcemap: false,
  legalComments: "inline",
  logLevel: "info",
});
console.log("Built ../fdc3-agent.js");