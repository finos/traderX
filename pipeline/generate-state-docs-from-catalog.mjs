import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const root = path.resolve(__dirname, '..')

const catalogPath = path.join(root, 'catalog', 'state-catalog.json')
const stateDocsPath = path.join(root, 'docs', 'spec-kit', 'state-docs.md')
const visualLearningGraphsPath = path.join(root, 'docs', 'spec-kit', 'visual-learning-graphs.md')
const learningIndexPath = path.join(root, 'docs', 'learning', 'index.md')
const learningDir = path.join(root, 'docs', 'learning')

if (!fs.existsSync(catalogPath)) {
  console.error(`[fail] missing state catalog: ${catalogPath}`)
  process.exit(1)
}

const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'))
const states = Array.isArray(catalog.states) ? catalog.states : []
const checkMode = process.argv.includes('--check')
let checkFailures = 0

if (states.length === 0) {
  console.error('[fail] no states found in state catalog')
  process.exit(1)
}

const emitFile = (filePath, content) => {
  const normalized = content.endsWith('\n') ? content : `${content}\n`

  if (checkMode) {
    const existing = fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : null
    if (existing !== normalized) {
      console.error(`[fail] generated doc out of date: ${path.relative(root, filePath)}`)
      checkFailures += 1
    }
    return
  }

  fs.mkdirSync(path.dirname(filePath), {recursive: true})
  fs.writeFileSync(filePath, normalized, 'utf8')
}

const repoWebBase = 'https://github.com/finos/traderX'
const sourceAuthoringBranch = 'feature/agentic-renovation'
const stripNumericPrefix = (stateId) => stateId.replace(/^[0-9]{3}-/, '')
const stateNumber = (stateId) => stateId.match(/^([0-9]{3})-/)?.[1] ?? stateId
const specRouteFor = (stateId) => `/specs/${stripNumericPrefix(stateId)}`
const learningRouteFor = (stateId) => `/docs/learning/state-${stateId}`
const learningPathFor = (stateId) => path.join(learningDir, `state-${stateId}.md`)
const branchLinkFor = (branch) => `${repoWebBase}/tree/${branch}`
const compareLinkFor = (baseBranch, headBranch) =>
  `${repoWebBase}/compare/${encodeURIComponent(baseBranch)}...${encodeURIComponent(headBranch)}`
const adrRouteFor = (recordPath) => {
  if (!recordPath) {
    return null
  }
  const normalized = recordPath.replace(/\\/g, '/')
  if (!normalized.startsWith('docs/') || !normalized.endsWith('.md')) {
    return null
  }
  return `/docs/${normalized.slice('docs/'.length, -'.md'.length)}`
}

const stateById = new Map(states.map((state) => [state.id, state]))
const orderedStates = [...states]
const convergenceStates = orderedStates.filter((state) => state.isConvergence === true)

const nextStateIdsFor = (stateId) =>
  states.filter((candidate) => (candidate.previous ?? []).includes(stateId)).map((state) => state.id)

const dottedParentIdsFor = (state) => Array.isArray(state.dottedParents) ? state.dottedParents : []
const convergenceLevelFor = (state) => state.convergenceLevel ?? 'none'
const primaryLineageRoleFor = (state) => state.primaryLineageRole ?? 'canonical'
const isConvergenceState = (state) => state.isConvergence === true
const convergenceDocAnchorFor = (level) => `/docs/spec-kit/convergence-states#${String(level || 'none').toLowerCase()}`

const nearestConvergenceNeighborsFor = (stateId) => {
  const index = convergenceStates.findIndex((state) => state.id === stateId)
  if (index < 0) {
    return {previous: null, next: null}
  }
  return {
    previous: convergenceStates[index - 1]?.id ?? null,
    next: convergenceStates[index + 1]?.id ?? null
  }
}

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

const stateDocRouteIfExists = (state, filename, routeSuffix) => {
  const absolute = path.join(root, state.featurePack, filename)
  if (!fs.existsSync(absolute)) {
    return null
  }
  return `${specRouteFor(state.id)}/${routeSuffix}`
}

const normalizeNone = (value) =>
  /^(none\.?|n\/a)$/i.test(value.trim())

const parseFunctionalDelta = (featurePack) => {
  const deltaPath = path.join(root, featurePack, 'requirements', 'functional-delta.md')
  if (!fs.existsSync(deltaPath)) {
    return []
  }

  const content = fs.readFileSync(deltaPath, 'utf8')
  const lines = content.split('\n')
  const sections = new Map()
  let currentSection = ''

  for (const line of lines) {
    const headingMatch = line.match(/^##\s+(.*)\s*$/)
    if (headingMatch) {
      currentSection = headingMatch[1].trim()
      if (!sections.has(currentSection)) {
        sections.set(currentSection, [])
      }
      continue
    }

    const bulletMatch = line.trim().match(/^-\s+(.*)$/)
    if (!bulletMatch || !currentSection) {
      continue
    }

    const value = bulletMatch[1].trim()
    if (!value || normalizeNone(value)) {
      continue
    }
    sections.get(currentSection).push(value)
  }

  const orderedSections = ['Added', 'Changed', 'Removed', 'Flow Impact']
  const result = []
  for (const sectionName of orderedSections) {
    const bullets = sections.get(sectionName) ?? []
    for (const bullet of bullets) {
      result.push(`**${sectionName}:** ${bullet}`)
      if (result.length >= 8) {
        return result
      }
    }
  }
  return result
}

const parseFunctionalRequirements = (featurePack) => {
  const specPath = path.join(root, featurePack, 'spec.md')
  if (!fs.existsSync(specPath)) {
    return []
  }

  const content = fs.readFileSync(specPath, 'utf8')
  const bullets = []
  const lines = content.split('\n')
  for (const line of lines) {
    const match = line.match(/^\s*-\s+\*\*FR-[0-9]+\*\*:\s+(.*)$/)
    if (!match) {
      continue
    }
    const value = match[1].trim().replace(/\.$/, '')
    if (!value) {
      continue
    }
    bullets.push(value)
    if (bullets.length >= 4) {
      break
    }
  }
  return bullets.map((item) => `**Functional intent:** ${item}.`)
}

const fixedSummaryByState = {
  '001-baseline-uncontainerized-parity': [
    '**Code focus:** Establishes the full baseline service set and Angular UI in a local multi-process runtime.',
    '**Runtime behavior:** Uses explicit host ports and direct cross-origin service calls.',
    '**Learning takeaway:** This is the reference implementation all later state diffs are measured against.'
  ],
  '002-edge-proxy-uncontainerized': [
    '**Code focus:** Adds an edge proxy component and routes browser traffic through one origin.',
    '**Runtime behavior:** Keeps services uncontainerized while reducing client-side cross-origin complexity.',
    '**Learning takeaway:** Introduces ingress-style edge concerns before containerization.'
  ],
  '003-containerized-compose-runtime': [
    '**Code focus:** Adds Dockerfiles and Compose assembly for all baseline services.',
    '**Runtime behavior:** Keeps behavior from state 002 but moves orchestration to containers.',
    '**Learning takeaway:** Establishes the containerized baseline that other architecture branches build from.'
  ]
}

const plainEnglishDeltaFor = (state) => {
  const fixed = fixedSummaryByState[state.id]
  if (fixed) {
    return fixed
  }
  const parsedDelta = parseFunctionalDelta(state.featurePack)
  if (parsedDelta.length > 0) {
    return parsedDelta
  }
  const frFallback = parseFunctionalRequirements(state.featurePack)
  if (frFallback.length > 0) {
    return frFallback
  }
  return ['No functional delta summary is currently available in this state pack.']
}

const linkedStateList = (ids) => {
  if (!ids || ids.length === 0) {
    return 'none'
  }
  return ids.map((id) => `[${id}](${learningRouteFor(id)})`).join(', ')
}

const compareLinksMarkdown = (state, previousIds) => {
  const headBranch = state.publish?.branch
  if (!headBranch || previousIds.length === 0) {
    return ['No previous-state compare link for this state.']
  }

  const links = []
  for (const prevId of previousIds) {
    const prevState = stateById.get(prevId)
    const baseBranch = prevState?.publish?.branch
    if (!baseBranch) {
      continue
    }
    links.push(
      `Compare against \`${prevId}\`: [${baseBranch}...${headBranch}](${compareLinkFor(baseBranch, headBranch)})`
    )
  }
  return links.length > 0 ? links : ['No previous-state compare link for this state.']
}

const writeLearningGuides = () => {
  const expectedGuideFiles = new Set()

  for (const state of states) {
    const previousIds = Array.isArray(state.previous) ? state.previous : []
    const nextIds = nextStateIdsFor(state.id)
    const dottedParentIds = dottedParentIdsFor(state)
    const convergenceLevel = convergenceLevelFor(state)
    const lineageRole = primaryLineageRoleFor(state)
    const convergenceNeighbors = nearestConvergenceNeighborsFor(state.id)
    const specRoute = specRouteFor(state.id)
    const architectureRoute = `${specRoute}/system/architecture`
    const topologyRoute = topologyRouteFor(state)
    const generatedBranch = state.publish?.branch
    const generatedBranchLink = generatedBranch ? branchLinkFor(generatedBranch) : null
    const compareLinks = compareLinksMarkdown(state, previousIds)
    const deltaBullets = plainEnglishDeltaFor(state)
    const runtimeCommand = state.generation?.runtime ?? state.generation?.entrypoint ?? 'not defined'
    const adrRoute = adrRouteFor(state.decisionRecord)
    const researchRoute = stateDocRouteIfExists(state, 'research.md', 'research')
    const dataModelRoute = stateDocRouteIfExists(state, 'data-model.md', 'data-model')
    const quickstartRoute = stateDocRouteIfExists(state, 'quickstart.md', 'quickstart')
    const routePath = learningPathFor(state.id)
    expectedGuideFiles.add(path.basename(routePath))

    const body = `---
title: "State ${stateNumber(state.id)}: ${state.title}"
---

# State ${stateNumber(state.id)} Learning Guide

## Position In Learning Graph

- Previous state(s): ${linkedStateList(previousIds)}
- Dotted-line parent(s): ${linkedStateList(dottedParentIds)}
- Next state(s): ${linkedStateList(nextIds)}

## Convergence Metadata

- Convergence state: \`${isConvergenceState(state) ? 'yes' : 'no'}\`
- Convergence level: \`${convergenceLevel}\`
- Lineage role: \`${lineageRole}\`
- Nearest previous convergence: ${convergenceNeighbors.previous ? `[${convergenceNeighbors.previous}](${learningRouteFor(convergenceNeighbors.previous)})` : '`none`'}
- Nearest next convergence: ${convergenceNeighbors.next ? `[${convergenceNeighbors.next}](${learningRouteFor(convergenceNeighbors.next)})` : '`none`'}

## Rendered Code

- Generated branch: ${generatedBranch ? `[${generatedBranch}](${generatedBranchLink})` : '`n/a`'}
- Authoring branch (spec source): [${sourceAuthoringBranch}](${branchLinkFor(sourceAuthoringBranch)})

## Code Comparison With Previous State

${compareLinks.map((line) => `- ${line}`).join('\n')}

## Plain-English Code Delta

${deltaBullets.map((line) => `- ${line}`).join('\n')}

## Run This State

\`\`\`bash
${runtimeCommand}
\`\`\`

## Canonical Spec Links

- State spec pack: [${specRoute}](${specRoute})
- Architecture: [${architectureRoute}](${architectureRoute})
- Flows / topology: [${topologyRoute}](${topologyRoute})
- Research: ${researchRoute ? `[link](${researchRoute})` : '`n/a`'}
- Data model: ${dataModelRoute ? `[link](${dataModelRoute})` : '`n/a`'}
- Quickstart: ${quickstartRoute ? `[link](${quickstartRoute})` : '`n/a`'}
${adrRoute ? `- State ADR: [link](${adrRoute})` : ''}
`

    emitFile(routePath, body)
  }

  const existingGuideFiles = fs.existsSync(learningDir)
    ? fs.readdirSync(learningDir).filter((name) => /^state-.*\.md$/.test(name))
    : []

  for (const name of existingGuideFiles) {
    if (expectedGuideFiles.has(name)) {
      continue
    }

    const stalePath = path.join(learningDir, name)
    if (checkMode) {
      console.error(`[fail] stale learning guide not in catalog: ${path.relative(root, stalePath)}`)
      checkFailures += 1
    } else {
      fs.unlinkSync(stalePath)
    }
  }
}

const writeLearningIndex = () => {
  const rows = states.map((state) => {
    const specRoute = specRouteFor(state.id)
    const learningRoute = learningRouteFor(state.id)
    const branchName = state.publish?.branch ?? 'n/a'
    const branchCell = branchName === 'n/a'
      ? '`n/a`'
      : `[${branchName}](${branchLinkFor(branchName)})`
    const previousIds = Array.isArray(state.previous) ? state.previous : []
    const dottedParentIds = dottedParentIdsFor(state)
    const convergenceLevel = convergenceLevelFor(state)
    const convergenceCell = isConvergenceState(state) ? `\`${convergenceLevel}\`` : '`none`'
    const dottedCell = dottedParentIds.length === 0
      ? '`none`'
      : dottedParentIds.map((id) => `[${id}](${learningRouteFor(id)})`).join('<br/>')
    const adrRoute = adrRouteFor(state.decisionRecord)
    const adrCell = adrRoute ? `[link](${adrRoute})` : '`n/a`'
    const previousCell = previousIds.length === 0
      ? '`none`'
      : previousIds.map((id) => `[${id}](${learningRouteFor(id)})`).join('<br/>')
    const compareCell = compareLinksMarkdown(state, previousIds)
      .map((line) => {
        const urlMatch = line.match(/\((https:\/\/[^)]+)\)$/)
        return urlMatch ? `[link](${urlMatch[1]})` : '`n/a`'
      })
      .join('<br/>')

    return `| \`${state.id}\` | [link](${learningRoute}) | [link](${specRoute}) | ${branchCell} | ${convergenceCell} | ${dottedCell} | ${previousCell} | ${compareCell} | ${adrCell} |`
  })

  const body = `---
title: Learning Guides
---

# Learning Guides

This section is the developer-focused learning layer for generated TraderX code states.

Canonical requirements, contracts, and architecture remain in \`specs/**\`.  
These guides explain how to read each generated code snapshot, compare it to previous states, and understand the code delta in plain English.

For the visual progression map, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Guide Catalog

| State | Learning Guide | Spec Pack | Generated Code Branch | Convergence | Dotted Parents | Previous State(s) | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
${rows.join('\n')}

## How To Use This Section

1. Open a state guide from this catalog.
2. Use the GitHub compare link to inspect exact code changes against previous state(s).
3. Read the plain-English delta for rationale and intent.
4. Follow links back to spec architecture/flows/contracts when you need system context.

## Recommended Starting Points For New State Design

${convergenceStates.map((state) => `- \`${state.id}\` (${convergenceLevelFor(state)}): ${state.title}`).join('\n')}
`

  emitFile(learningIndexPath, body)
}

const writeStateDocs = () => {
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
    const branchCell = branchName !== 'n/a' ? `[${branchName}](${branchLinkFor(branchName)})` : '`n/a`'
    const researchRoute = stateDocRouteIfExists(state, 'research.md', 'research')
    const dataModelRoute = stateDocRouteIfExists(state, 'data-model.md', 'data-model')
    const quickstartRoute = stateDocRouteIfExists(state, 'quickstart.md', 'quickstart')
    const researchCell = researchRoute ? `[link](${researchRoute})` : '`n/a`'
    const dataModelCell = dataModelRoute ? `[link](${dataModelRoute})` : '`n/a`'
    const quickstartCell = quickstartRoute ? `[link](${quickstartRoute})` : '`n/a`'
    const previousIds = Array.isArray(state.previous) ? state.previous : []
    const dottedParentIds = dottedParentIdsFor(state)
    const convergenceLevel = convergenceLevelFor(state)
    const convergenceCell = isConvergenceState(state) ? `\`${convergenceLevel}\`` : '`none`'
    const dottedCell = dottedParentIds.length === 0
      ? '`none`'
      : dottedParentIds.map((id) => `[${id}](${learningRouteFor(id)})`).join('<br/>')
    const adrRoute = adrRouteFor(state.decisionRecord)
    const adrCell = adrRoute ? `[link](${adrRoute})` : '`n/a`'
    const compareCell = compareLinksMarkdown(state, previousIds)
      .map((line) => {
        const urlMatch = line.match(/\((https:\/\/[^)]+)\)$/)
        return urlMatch ? `[link](${urlMatch[1]})` : '`n/a`'
      })
      .join('<br/>')

    return `| \`${state.id}\` | ${state.status} | ${convergenceCell} | ${dottedCell} | [link](${learningRoute}) | [link](${specRoute}) | [link](${architectureRoute}) | [link](${topologyRoute}) | ${researchCell} | ${dataModelCell} | ${quickstartCell} | ${branchCell} | ${compareCell} | ${adrCell} |`
  })

  const body = `---
title: State Docs
hide_table_of_contents: true
---

# State Docs

This page is generated from \`catalog/state-catalog.json\` and links the most important per-state artifacts.

For progression context, see [Visual Learning Paths](/docs/spec-kit/visual-learning-graphs).

## State Catalog

| State | Status | Convergence | Dotted Parents | Learning Guide | Spec Pack | Architecture | Flows / Topology | Research | Data Model | Quickstart | Generated Code Branch | Compare To Previous | ADR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
${rows.join('\n')}

## API Explorer by State

- Current API explorer route: [/api](/api)
- Current scope: \`${activeApiState.id}\`
- Source contracts: \`${activeApiContractsRoot}\`
- Future plan: add per-state API explorer selectors as additional state contract sets are published.

## How This Page Is Maintained

- Source catalog: \`catalog/state-catalog.json\`
- Regenerate docs pages:

\`\`\`bash
bash pipeline/refresh-state-docs.sh
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

  emitFile(stateDocsPath, body)
}

const trackKeyFor = (state) => state.track ?? 'baseline'
const trackLabelFor = (trackKey) => {
  if (trackKey === 'baseline') {
    return 'Baseline'
  }
  return trackKey.charAt(0).toUpperCase() + trackKey.slice(1)
}

const mermaidNodeIdFor = (stateId) => `S${stateId.replace(/[^a-zA-Z0-9]/g, '_')}`
const mermaidLabelFor = (state) => {
  const convergenceBadge = isConvergenceState(state) ? ` [${convergenceLevelFor(state)}]` : ''
  return `${stateNumber(state.id)}: ${state.title}${convergenceBadge}`.replace(/"/g, '\\"')
}

const writeVisualLearningGraphs = () => {
  const sortedStates = [...states]

  const nodeLines = sortedStates.map((state) =>
    `  ${mermaidNodeIdFor(state.id)}["${mermaidLabelFor(state)}"]`
  )

  const edgeLines = []
  const dottedEdgeLines = []
  for (const state of sortedStates) {
    const previousIds = Array.isArray(state.previous) ? state.previous : []
    for (const previousId of previousIds) {
      const linkType = state.status === 'implemented' ? '-->' : '-.->'
      edgeLines.push(`  ${mermaidNodeIdFor(previousId)} ${linkType} ${mermaidNodeIdFor(state.id)}`)
    }
    for (const dottedParentId of dottedParentIdsFor(state)) {
      dottedEdgeLines.push(`  ${mermaidNodeIdFor(dottedParentId)} -.-> ${mermaidNodeIdFor(state.id)}`)
    }
  }

  const clickLines = sortedStates.map((state) =>
    `  click ${mermaidNodeIdFor(state.id)} href "${specRouteFor(state.id)}" "Open State ${stateNumber(state.id)} Spec Pack"`
  )

  const trackOrder = ['prelude', 'baseline', 'architecture', 'nonfunctional', 'functional', 'devex']
  const trackStates = new Map(trackOrder.map((track) => [track, []]))
  for (const state of sortedStates) {
    const trackKey = trackKeyFor(state)
    if (!trackStates.has(trackKey)) {
      trackStates.set(trackKey, [])
    }
    trackStates.get(trackKey).push(state)
  }

  const swimlaneLines = ['flowchart TB']
  for (const trackKey of trackOrder) {
    const statesForTrack = trackStates.get(trackKey) ?? []
    if (statesForTrack.length === 0) {
      continue
    }
    swimlaneLines.push(`  subgraph ${trackKey.toUpperCase()}["${trackLabelFor(trackKey)} Track"]`)
    for (const state of statesForTrack) {
      swimlaneLines.push(`    ${mermaidNodeIdFor(state.id)}["${mermaidLabelFor(state)}"]`)
    }
    swimlaneLines.push('  end')
  }

  for (const [trackKey, statesForTrack] of trackStates.entries()) {
    if (trackOrder.includes(trackKey) || statesForTrack.length === 0) {
      continue
    }
    const safeId = trackKey.replace(/[^a-zA-Z0-9]/g, '_').toUpperCase()
    swimlaneLines.push(`  subgraph ${safeId}["${trackLabelFor(trackKey)} Track"]`)
    for (const state of statesForTrack) {
      swimlaneLines.push(`    ${mermaidNodeIdFor(state.id)}["${mermaidLabelFor(state)}"]`)
    }
    swimlaneLines.push('  end')
  }

  swimlaneLines.push(...edgeLines)
  swimlaneLines.push(...dottedEdgeLines)

  const convergenceClassLines = []
  for (const state of sortedStates) {
    if (isConvergenceState(state)) {
      convergenceClassLines.push(`  class ${mermaidNodeIdFor(state.id)} convergence`)
    }
  }

  const tableRows = sortedStates.map((state) => {
    const specRoute = specRouteFor(state.id)
    const architectureRoute = `${specRoute}/system/architecture`
    const topologyRoute = topologyRouteFor(state)
    const learningRoute = learningRouteFor(state.id)
    const convergenceLevel = convergenceLevelFor(state)
    const stateCell = isConvergenceState(state)
      ? `**[\`${state.id}\`](${specRoute})** [(${convergenceLevel})](${convergenceDocAnchorFor(convergenceLevel)})`
      : `[\`${state.id}\`](${specRoute})`
    const branchName = state.publish?.branch ?? 'n/a'
    const branchCell = branchName === 'n/a'
      ? '`n/a`'
      : `[${branchName}](${branchLinkFor(branchName)})`

    return `| ${stateCell} | [link](${specRoute}) | [link](${architectureRoute}) | [link](${topologyRoute}) | [link](${learningRoute}) | ${branchCell} |`
  })

  const convergenceFlowLines = ['flowchart LR']
  for (const state of convergenceStates) {
    convergenceFlowLines.push(`  ${mermaidNodeIdFor(state.id)}["${mermaidLabelFor(state)}"]`)
  }
  for (let i = 1; i < convergenceStates.length; i += 1) {
    const previous = convergenceStates[i - 1]
    const current = convergenceStates[i]
    convergenceFlowLines.push(`  ${mermaidNodeIdFor(previous.id)} --> ${mermaidNodeIdFor(current.id)}`)
  }
  for (const state of convergenceStates) {
    convergenceFlowLines.push(
      `  click ${mermaidNodeIdFor(state.id)} href "${specRouteFor(state.id)}" "Open ${state.id}"`
    )
  }

  const body = `---
title: Visual Learning Paths
---

# Visual Learning Paths

This page is generated from \`catalog/state-catalog.json\`.
Green nodes represent convergence checkpoints (C-level milestones such as \`[C0]\`, \`[C1]\`, \`[C2]\`, \`[C3]\`).

## Convergence-Level Graph

This high-level view shows only the canonical convergence progression from \`C0\` to \`C3\`.

\`\`\`mermaid
${convergenceFlowLines.join('\n')}
  classDef convergence fill:#d7f5dd,stroke:#2e7d32,stroke-width:2px
${convergenceClassLines.join('\n')}
\`\`\`

## Official Current Graph

\`\`\`mermaid
flowchart TB
${nodeLines.join('\n')}
${edgeLines.join('\n')}
${dottedEdgeLines.join('\n')}
${clickLines.join('\n')}
  classDef convergence fill:#d7f5dd,stroke:#2e7d32,stroke-width:2px
${convergenceClassLines.join('\n')}
\`\`\`

## State To Artifact Mapping

| State | Spec Pack | Architecture | Flows / Runtime Topology | Learning Guide | Generated Code Branch |
| --- | --- | --- | --- | --- | --- |
${tableRows.join('\n')}

## Swimlane View

\`\`\`mermaid
${swimlaneLines.join('\n')}
  classDef convergence fill:#d7f5dd,stroke:#2e7d32,stroke-width:2px
\`\`\`

Use \`catalog/state-catalog.json\` as the canonical state lineage record.
`

  emitFile(visualLearningGraphsPath, body)
}

writeLearningGuides()
writeLearningIndex()
writeStateDocs()
writeVisualLearningGraphs()

if (checkMode) {
  if (checkFailures > 0) {
    console.error(`[fail] state-doc generation check found ${checkFailures} out-of-date artifact(s)`)
    process.exit(1)
  }
  console.log('[ok] state-doc generation artifacts are up to date')
  process.exit(0)
}

console.log(`[ok] wrote ${path.relative(root, stateDocsPath)}`)
console.log(`[ok] wrote ${path.relative(root, visualLearningGraphsPath)}`)
console.log(`[ok] wrote ${path.relative(root, learningIndexPath)}`)
console.log('[ok] wrote docs/learning/state-*.md')
