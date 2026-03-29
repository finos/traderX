import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const root = path.resolve(__dirname, '..', '..')
const catalogPath = path.join(root, 'catalog', 'state-catalog.json')
const apiDocsDir = path.join(root, 'generated', 'api-docs')
const componentsDir = path.join(root, 'specs', '001-baseline-uncontainerized-parity', 'components')
const outFile = path.join(apiDocsDir, 'index.mdx')

if (!fs.existsSync(catalogPath)) {
  console.error(`[fail] missing state catalog: ${catalogPath}`)
  process.exit(1)
}

fs.mkdirSync(apiDocsDir, {recursive: true})

const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'))
const states = Array.isArray(catalog.states) ? catalog.states : []

if (states.length === 0) {
  console.error('[fail] no states defined in state catalog')
  process.exit(1)
}

const toTitle = (serviceDir) =>
  serviceDir
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')

const extractSectionLines = (content, sectionHeading) => {
  const section = new RegExp(`## ${sectionHeading}\\n\\n([\\s\\S]*?)(?:\\n## |$)`).exec(content)
  if (!section) {
    return []
  }

  return section[1]
    .trim()
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('- '))
    .map((line) => line.replace(/^- /, '').trim())
}

const activeStateId = process.env.TRADERX_API_STATE_ID ??
  catalog.docs?.apiExplorer?.activeStateId ??
  states[0].id
const activeState = states.find((state) => state.id === activeStateId) ?? states[0]

const serviceDirs = fs
  .readdirSync(apiDocsDir, {withFileTypes: true})
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort((a, b) => a.localeCompare(b))

const serviceLinks = serviceDirs.map((serviceDir) => {
  const servicePath = path.join(apiDocsDir, serviceDir)
  const files = fs.readdirSync(servicePath)
  const infoFile = files.find((file) => file.endsWith('.info.mdx'))
  const apiFile = files.find((file) => file.endsWith('.api.mdx'))
  const componentPath = path.join(componentsDir, `${serviceDir}.md`)
  const responsibilities = fs.existsSync(componentPath)
    ? extractSectionLines(fs.readFileSync(componentPath, 'utf8'), 'Responsibilities')
    : []

  const routeSlug = infoFile
    ? infoFile.replace(/\.info\.mdx$/, '')
    : apiFile
      ? apiFile.replace(/\.api\.mdx$/, '')
      : serviceDir

  return {
    label: toTitle(serviceDir),
    route: `/api/${serviceDir}/${routeSlug}`,
    componentRoute: `/specs/001-baseline-uncontainerized-parity/components/${serviceDir}`,
    responsibilities,
  }
})

const stateList = states
  .map((state) => `- \`${state.id}\` (${state.status})`)
  .join('\n')

const contractsRoot = `${activeState.featurePack}/contracts/**/openapi.yaml`

const servicesBlock = serviceLinks.length === 0
  ? '- No generated API docs found. Run `npm --prefix website run gen:api-docs`.'
  : serviceLinks
      .map((item) => {
        const purposeLines = item.responsibilities.length === 0
          ? '- Purpose: See linked component spec.'
          : item.responsibilities.map((line) => `- ${line}`)
        return [
          `### [${item.label}](${item.route})`,
          '',
          ...purposeLines,
          '',
          `Spec source: [\`${item.label} component spec\`](${item.componentRoute})`,
        ].join('\n')
      })
      .join('\n\n')

const content = `---
title: API Explorer
---

# API Explorer

This explorer is currently scoped to \`${activeState.id}\`.

Source of truth: \`${contractsRoot}\`

## Services

${servicesBlock}

## Known States (Catalog)

${stateList}

As additional states define their own OpenAPI contracts, this landing page will add state selectors.
`

fs.writeFileSync(outFile, content, 'utf8')
console.log(`[ok] wrote ${outFile}`)
