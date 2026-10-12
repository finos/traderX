const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const os = require('node:os')
const path = require('node:path')
const {generate, outputPath} = require('./generate-markdown-docs.cjs')

function html(url, body) {
  return `<html><head><link rel="canonical" href="${url}"></head><body>
    <nav>Sidebar content must not leak</nav><main><nav>Breadcrumbs</nav>
    <div class="markdown">${body}</div><footer>Edit this page</footer></main></body></html>`
}

test('published routes drive Markdown, coverage, and portable links under a base path', async t => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'traderx-markdown-'))
  t.after(() => fs.rm(dir, {recursive: true, force: true}))
  const origin = 'https://preview.example'
  await fs.writeFile(path.join(dir, 'guide.html'), html(`${origin}/traderX/docs/custom-slug`, `
    <h1>Guide</h1><p>Rendered MDX content <strong>survives</strong>.</p>
    <a href="/traderX/specs/baseline/spec#requirements">Specification</a>
    <img src="/traderX/img/diagram.png" alt="Architecture">
    <pre class="language-bash"><code><span>echo hi</span>\n<span>echo \`\`\`</span>\n</code></pre>
    <details><summary>Diagram source</summary><pre><code class="language-mermaid">flowchart LR\n A --&gt; B</code></pre></details>
    <table><thead><tr><th>State</th><th>Status</th></tr></thead><tbody><tr><td>001</td><td>Ready</td></tr></tbody></table>`))
  await fs.writeFile(path.join(dir, 'spec.html'), html(`${origin}/traderX/specs/baseline/spec`, '<h1>Spec</h1><h2 id="requirements">Requirements</h2><p>Required behavior.</p>'))
  await fs.writeFile(path.join(dir, 'constitution.html'), html(`${origin}/traderX/specify/memory/constitution`, '<h1>Constitution</h1><p>Principles.</p>'))
  await fs.writeFile(path.join(dir, '404.html'), '<main>Page not found</main>')
  const result = await generate(dir, '/traderX/')
  assert.equal(result.pages, 3)
  const guide = await fs.readFile(path.join(dir, 'docs/custom-slug.md'), 'utf8')
  assert.match(guide, /Rendered MDX content \*\*survives\*\*/)
  assert.match(guide, /https:\/\/preview.example\/traderX\/llms.txt/)
  assert.match(guide, /specs\/baseline\/spec.md#requirements/)
  assert.match(guide, /https:\/\/preview.example\/traderX\/img\/diagram.png/)
  assert.match(guide, /````bash\necho hi\necho ```\n````/)
  assert.match(guide, /```mermaid\nflowchart LR\n A --> B\n```/)
  assert.match(guide, /\| State \| Status \|/)
  assert.doesNotMatch(guide, /Sidebar|Breadcrumbs|Edit this page/)
  for (const section of ['Guides', 'Specifications', 'Constitution']) assert.ok(result.index.includes(`## ${section}`))
  const links = [...result.index.matchAll(/\]\((https:\/\/[^)]+)\)/g)].map(match => new URL(match[1]))
  assert.equal(links.length, 3)
  for (const link of links) assert.ok((await fs.stat(outputPath(dir, link.pathname, '/traderX/'))).size)
  await assert.rejects(fs.stat(path.join(dir, '404.md')))
})

test('rejects malformed route mappings instead of silently generating broken indexes', async t => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'traderx-markdown-'))
  t.after(() => fs.rm(dir, {recursive: true, force: true}))
  await assert.rejects(generate(dir), /No rendered documentation/)
  assert.throws(() => outputPath(dir, '/outside/page.md', '/docs/'), /outside base path/)
  assert.throws(() => outputPath(dir, '/%2e%2e/escape.md', '/'), /escapes output/)
  const page = html('https://example.org/docs/same-slug', '<h1>Same</h1>')
  await fs.writeFile(path.join(dir, 'a.html'), page)
  await fs.writeFile(path.join(dir, 'b.html'), page)
  await assert.rejects(generate(dir), /Duplicate documentation route/)
})
