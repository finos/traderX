import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const root = path.resolve(__dirname, '..')

const catalogPath = path.join(root, 'catalog', 'state-catalog.json')
const outputPath = path.join(root, 'docs', 'spec-kit', 'state-docs.md')

if (!fs.existsSync(catalogPath)) {
  console.error(`[fail] missing state catalog: ${catalogPath}`)
  process.exit(1)
}

const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'))
const states = Array.isArray(catalog.states) ? catalog.states : []

if (states.length === 0) {
  console.error('[fail] no states found in state catalog')
  process.exit(1)
}

const stripNumericPrefix = (stateId) => stateId.replace(/^[0-9]{3}-/, '')
const specRouteFor = (stateId) => `/specs/${stripNumericPrefix(stateId)}`
const learningRouteFor = (stateId) => `/docs/learning/state-${stateId}`
const repoWebBase = 'https://github.com/finos/traderX'

const topologyRouteFor = (state) => {
  const featurePackDir = path.join(root, state.featurePack)
  const runtimeTopologyPath = path.join(featurePackDir, 'system', 'runtime-topology.md')
  const flowsPath = path.join(featurePackDir, 'system', 'end-to-end-flows.md')
  if (fs.existsSync(runtimeTopologyPath)) {
    return `${specRouteFor(state.id)}/system/runtime-topology`
  }
  if (fs.existsSync(flowsPath)) {
    return `${specRouteFor(state.id)}/system/end-to-end-flows`
  }
  return `${specRouteFor(state.id)}/system/system-context`
}

const apiExplorerConfig = catalog.docs?.apiExplorer ?? {}
const activeApiStateId = apiExplorerConfig.activeStateId ?? states[0].id
const activeApiState = states.find((state) => state.id === activeApiStateId) ?? states[0]
const activeApiContractsRoot = `${activeApiState.featurePack}/contracts/**/openapi.yaml`

const rows = states.map((state) => {
  const specRoute = specRouteFor(state.id)
  const architectureRoute = `${specRoute}/system/architecture`
  const topologyRoute = topologyRouteFor(state)
  const learningRoute = learningRouteFor(state.id)
  const branchName = state.publish?.branch ?? 'n/a'
  const branchLink = branchName !== 'n/a' ? `${repoWebBase}/tree/${branchName}` : ''
  const branchCell = branchName !== 'n/a' ? `[${branchName}](${branchLink})` : '`n/a`'

  return `| \`${state.id}\` | ${state.status} | [link](${learningRoute}) | [link](${specRoute}) | [link](${architectureRoute}) | [link](${topologyRoute}) | ${branchCell} |`
})

const body = `---
title: State Docs
hide_table_of_contents: true
---

# State Docs

This page is generated from \`catalog/state-catalog.json\` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Catalog

| State | Status | Learning Guide | Spec Pack | Architecture | Flows / Topology | Generated Code Branch |
| --- | --- | --- | --- | --- | --- | --- |
${rows.join('\n')}

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: \`${activeApiState.id}\`
- Source contracts: \`${activeApiContractsRoot}\`
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How This Page Is Maintained

- Source catalog: \`catalog/state-catalog.json\`
- Regenerate this page:

\`\`\`bash
node pipeline/generate-state-docs-from-catalog.mjs
\`\`\`

- State architecture docs are generated from:
  - \`specs/<state>/system/architecture.model.json\`
- Generate state architecture docs:

\`\`\`bash
bash pipeline/generate-state-architecture-doc.sh <state-id>
\`\`\`

- Generate all state architecture docs:

\`\`\`bash
bash pipeline/generate-all-architecture-docs.sh
\`\`\`
`

fs.writeFileSync(outputPath, body, 'utf8')
console.log(`[ok] wrote ${outputPath}`)
