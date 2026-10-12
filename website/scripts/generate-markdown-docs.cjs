// Use published HTML routes and rendered content, never source filenames: Docusaurus
// slugs, numeric prefixes, MDX, and multiple docs instances all change the output.
const fs = require('node:fs/promises')
const path = require('node:path')
const {load} = require('cheerio')
const TurndownService = require('turndown')
const {gfm} = require('turndown-plugin-gfm')

async function htmlFiles(dir) {
  const entries = await fs.readdir(dir, {withFileTypes: true})
  const files = await Promise.all(entries.map(entry => {
    const file = path.join(dir, entry.name)
    return entry.isDirectory() ? htmlFiles(file) : entry.name.endsWith('.html') ? [file] : []
  }))
  return files.flat().sort()
}

function markdownPath(url) {
  return `${url.pathname.replace(/\/$/, '') || '/index'}.md`
}

function outputPath(outDir, urlPath, basePath) {
  if (!urlPath.startsWith(basePath)) throw new Error(`Route outside base path: ${urlPath}`)
  const relative = decodeURIComponent(urlPath.slice(basePath.length))
  const target = path.resolve(outDir, relative)
  if (!target.startsWith(`${path.resolve(outDir)}${path.sep}`)) {
    throw new Error(`Route escapes output directory: ${urlPath}`)
  }
  return target
}

function convertPage(page, routes, indexUrl) {
  const $ = load(page.html)
  const content = $('main .markdown').first()
  content.find('button, .hash-link, script, style').remove()
  content.find('a[href], img[src]').each((_, element) => {
    const attribute = element.name === 'a' ? 'href' : 'src'
    const original = $(element).attr(attribute)
    if (!original || original.startsWith('#')) return
    const target = new URL(original, page.url)
    const route = routes.get(`${target.origin}${target.pathname.replace(/\/$/, '')}`)
    if (attribute === 'href' && route) target.pathname = markdownPath(route.url)
    $(element).attr(attribute, target.href)
  })
  const converter = new TurndownService({headingStyle: 'atx', codeBlockStyle: 'fenced'})
  converter.use(gfm)
  // Docusaurus code blocks contain token/line spans. Read text rather than
  // formatting spans, and use a fence longer than any literal backticks in code.
  converter.addRule('docusaurusCode', {
    filter: node => node.nodeName === 'PRE' && Boolean(node.querySelector('code')),
    replacement: (_, node) => {
      const code = node.querySelector('code')
      const text = code.textContent.replace(/\n$/, '')
      const language = `${node.className} ${code.className}`.match(/language-([\w+-]+)/)?.[1] || ''
      const longest = Math.max(0, ...(text.match(/`+/g) || []).map(value => value.length))
      const fence = '`'.repeat(Math.max(3, longest + 1))
      return `\n\n${fence}${language}\n${text}\n${fence}\n\n`
    },
  })
  let markdown = converter.turndown(content.html())
  const directive = `> For the complete documentation index, see [llms.txt](${indexUrl}).`
  // Keep the document's real heading; put discovery before the body content.
  if (markdown.startsWith('# ')) markdown = markdown.replace(/^(# [^\n]+)\n*/, `$1\n\n${directive}\n\n`)
  else markdown = `# ${page.title}\n\n${directive}\n\n${markdown}`
  return `${markdown.trim()}\n`
}

async function generate(outDir, basePath = '/') {
  basePath = `/${basePath.replace(/^\/+|\/+$/g, '')}/`.replace('//', '/')
  const pages = []
  for (const file of await htmlFiles(outDir)) {
    const html = await fs.readFile(file, 'utf8')
    const $ = load(html)
    if (!$('main .markdown').length) continue
    const canonical = $('link[rel="canonical"]').attr('href')
    if (!canonical) throw new Error(`Missing canonical URL: ${file}`)
    const url = new URL(canonical)
    const title = $('main .markdown h1').first().text().trim() || $('title').text()
    pages.push({html, url, title})
  }
  if (!pages.length) throw new Error('No rendered documentation found')
  const routes = new Map()
  for (const page of pages) {
    const key = `${page.url.origin}${page.url.pathname.replace(/\/$/, '')}`
    if (routes.has(key)) throw new Error(`Duplicate documentation route: ${key}`)
    routes.set(key, page)
  }
  const indexUrl = new URL(`${basePath}llms.txt`, pages[0].url.origin).href
  const sections = new Map()
  const documents = []
  const targets = new Set()
  for (const page of pages) {
    const mdPath = markdownPath(page.url)
    const target = outputPath(outDir, mdPath, basePath)
    if (targets.has(target)) throw new Error(`Duplicate Markdown output: ${mdPath}`)
    targets.add(target)
    const markdown = convertPage(page, routes, indexUrl)
    await fs.mkdir(path.dirname(target), {recursive: true})
    await fs.writeFile(target, markdown)
    documents.push(markdown)
    const route = page.url.pathname.slice(basePath.length)
    const section = route.startsWith('specs') ? 'Specifications' : route.startsWith('specify') ? 'Constitution' : 'Guides'
    if (!sections.has(section)) sections.set(section, [])
    const title = page.title.replace(/[\r\n]/g, ' ').replace(/[\\[\]]/g, '\\$&')
    sections.get(section).push(`- [${title}](${new URL(mdPath, page.url.origin).href})`)
  }
  const index = '# TraderX\n\n> Documentation, specifications, and project constitution.\n\n' +
    [...sections].map(([name, links]) => `## ${name}\n\n${links.join('\n')}`).join('\n\n') + '\n'
  await fs.writeFile(path.join(outDir, 'llms.txt'), index)
  await fs.writeFile(path.join(outDir, 'llms-full.txt'), '# TraderX documentation\n\n' + documents.join('\n---\n\n'))
  // Fail the build for missing or empty indexed targets, including route aliases.
  for (const target of targets) {
    if (!(await fs.stat(target)).size) throw new Error(`Empty Markdown file: ${target}`)
  }
  console.log(`[markdown] generated and verified ${pages.length} pages across ${sections.size} sections`)
  return {pages: pages.length, index}
}

module.exports = {generate, convertPage, outputPath}
if (require.main === module) {
  generate(path.resolve(process.cwd(), 'build'), process.env.DOCUSAURUS_BASE_URL || '/')
    .catch(error => { console.error(error); process.exitCode = 1 })
}
