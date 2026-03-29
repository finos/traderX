import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const root = path.resolve(__dirname, '..', '..')
const apiDocsDir = path.join(root, 'generated', 'api-docs')
const componentsDir = path.join(root, 'specs', '001-baseline-uncontainerized-parity', 'components')
const flowsDocRoute = '/specs/001-baseline-uncontainerized-parity/system/end-to-end-flows'

if (!fs.existsSync(apiDocsDir)) {
  console.error(`[fail] missing api docs dir: ${apiDocsDir}`)
  process.exit(1)
}

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

const flowLink = (flowToken) => {
  const token = flowToken.replace(/`/g, '')
  const match = token.match(/^(STARTUP|F\d+)/)
  if (!match) {
    return `\`${token}\``
  }
  const flowId = match[1]
  const anchor = flowId.toLowerCase()
  return `[\`${flowId}\`](${flowsDocRoute}#${anchor})`
}

const toRoute = (serviceDir) => `/specs/001-baseline-uncontainerized-parity/components/${serviceDir}`

const serviceDirs = fs
  .readdirSync(apiDocsDir, {withFileTypes: true})
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort((a, b) => a.localeCompare(b))

for (const serviceDir of serviceDirs) {
  const componentPath = path.join(componentsDir, `${serviceDir}.md`)
  if (!fs.existsSync(componentPath)) {
    continue
  }

  const servicePath = path.join(apiDocsDir, serviceDir)
  const infoFile = fs.readdirSync(servicePath).find((file) => file.endsWith('.info.mdx'))
  if (!infoFile) {
    continue
  }

  const componentMd = fs.readFileSync(componentPath, 'utf8')
  const responsibilities = extractSectionLines(componentMd, 'Responsibilities')
  const coveredFlows = extractSectionLines(componentMd, 'Covered Flows')
  const requirementCoverage = extractSectionLines(componentMd, 'Requirement Coverage')

  const overviewBlock = [
    '',
    '## Service Purpose (Spec)',
    '',
    ...responsibilities.map((item) => `- ${item}`),
    '',
    '## Coverage Links',
    '',
    `- Component spec: [\`${serviceDir}\`](${toRoute(serviceDir)})`,
    ...(
      coveredFlows.length > 0
        ? [
            `- Covered flows: ${coveredFlows.map((flow) => flowLink(flow)).join(', ')}`,
          ]
        : []
    ),
    ...(
      requirementCoverage.length > 0
        ? requirementCoverage.map((reqLine, idx) =>
            idx === 0
              ? `- Requirement coverage: ${reqLine}`
              : `- Additional coverage: ${reqLine}`,
          )
        : []
    ),
    '',
  ].join('\n')

  const infoPath = path.join(servicePath, infoFile)
  const original = fs.readFileSync(infoPath, 'utf8')
  const marker = '\n## Service Purpose (Spec)\n'
  const stripped = original.includes(marker)
    ? original.slice(0, original.indexOf(marker)).replace(/\s*$/, '\n')
    : original.replace(/\s*$/, '\n')

  fs.writeFileSync(infoPath, `${stripped}${overviewBlock}`, 'utf8')
  console.log(`[ok] enriched ${infoPath}`)
}
