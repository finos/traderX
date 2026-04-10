import fs from 'node:fs/promises'
import path from 'node:path'

const outDir = path.resolve(process.cwd(), 'build')
const targets = ['llms.txt', 'llms-full.txt']
const docsUrl = process.env.DOCUSAURUS_URL
const docsBaseUrl = process.env.DOCUSAURUS_BASE_URL || '/'

function normalizeBasePath(baseUrl) {
  if (!baseUrl || baseUrl === '/') {
    return '/'
  }
  return `/${baseUrl.replace(/^\/+|\/+$/g, '')}/`
}

function addSiteBaseToInternalLinks(content) {
  if (!docsUrl) {
    return content
  }

  const normalizedBase = normalizeBasePath(docsBaseUrl)
  if (normalizedBase === '/') {
    return content
  }

  let origin
  try {
    origin = new URL(docsUrl).origin
  } catch {
    return content
  }

  const internalRoots = ['docs', 'specs', 'api', 'specify', 'adr', 'blog']
  let updated = content

  for (const root of internalRoots) {
    const withoutBase = `${origin}/${root}`
    const withBase = `${origin}${normalizedBase}${root}`
    updated = updated.replaceAll(withoutBase, withBase)
  }

  return updated
}

function normalize(content) {
  // docusaurus-plugin-llms currently emits `docs/../docs/*` when docs live outside `website/`.
  const normalized = content
    .replaceAll('/docs/../docs/', '/docs/')
    .replaceAll('/docs/../docs', '/docs')
  return addSiteBaseToInternalLinks(normalized)
}

async function normalizeFile(fileName) {
  const filePath = path.join(outDir, fileName)

  try {
    const original = await fs.readFile(filePath, 'utf8')
    const updated = normalize(original)
    if (updated !== original) {
      await fs.writeFile(filePath, updated, 'utf8')
      console.log(`[llms] normalized links in ${fileName}`)
    }
  } catch (error) {
    if (error && error.code === 'ENOENT') {
      console.log(`[llms] skipped ${fileName} (not generated)`)
      return
    }
    throw error
  }
}

for (const target of targets) {
  await normalizeFile(target)
}
