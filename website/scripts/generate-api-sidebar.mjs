import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const root = path.resolve(__dirname, '..', '..')
const apiDocsDir = path.join(root, 'generated', 'api-docs')
const outFile = path.join(root, 'website', 'traderspec-api.sidebars.js')

if (!fs.existsSync(apiDocsDir)) {
  console.error(`[fail] missing api docs dir: ${apiDocsDir}`)
  process.exit(1)
}

const toTitle = (serviceDir) =>
  serviceDir
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')

const toDocId = (serviceDir, filename, suffix) =>
  `${serviceDir}/${filename.replace(suffix, '')}`

const serviceDirs = fs
  .readdirSync(apiDocsDir, {withFileTypes: true})
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort((a, b) => a.localeCompare(b))

const serviceItems = serviceDirs.map((serviceDir) => {
  const servicePath = path.join(apiDocsDir, serviceDir)
  const files = fs.readdirSync(servicePath).sort((a, b) => a.localeCompare(b))
  const infoFile = files.find((f) => f.endsWith('.info.mdx'))
  const operationFiles = files.filter((f) => f.endsWith('.api.mdx'))

  const items = operationFiles.map((filename) => ({
    type: 'doc',
    id: toDocId(serviceDir, filename, '.api.mdx'),
  }))

  const category = {
    type: 'category',
    label: toTitle(serviceDir),
    items,
  }

  if (infoFile) {
    category.link = {
      type: 'doc',
      id: toDocId(serviceDir, infoFile, '.info.mdx'),
    }
  }

  return category
})

const sidebar = {
  traderspecApiSidebar: [
    {
      type: 'category',
      label: 'API Explorer',
      link: {
        type: 'doc',
        id: 'index',
      },
      items: serviceItems,
    },
  ],
}

const output = `module.exports = ${JSON.stringify(sidebar, null, 2)};\n`
fs.writeFileSync(outFile, output, 'utf8')
console.log(`[ok] wrote ${outFile}`)
