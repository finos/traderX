# TraderX documentation website

The website uses Docusaurus 3. Its content comes from `docs/`, `specs/`, and
`.specify/`; configuration and frontend assets live in `website/`.

## Local development

Use Node.js 22, matching the docs publishing workflow and Netlify configuration.
From the repository root:

```sh
npm --prefix website ci --no-audit --no-fund
npm --prefix website start
```

The development site is available at <http://localhost:3000>.

## Production publishing

`.github/workflows/deploy-docusaurus-pages.yml` publishes
<https://traderx.finos.org> through GitHub Pages on pushes to `main` or manual
workflow dispatch. Netlify is used only for pull-request previews.

## Netlify pull-request previews

The root `netlify.toml` sets the base directory to `website`, runs
`pipeline/build-netlify-preview.sh`, and publishes `website/build`. The script
refreshes catalog-derived state docs just like the production workflow, then
builds with the preview URL as the Docusaurus site URL and `/` as its base path.
Preview responses include `X-Robots-Tag: noindex, nofollow`.

Connect the Netlify project to this GitHub repository and enable Deploy Previews
for pull requests targeting `main`. The GitHub integration then adds the preview
link and build status to each PR. This configuration cannot install or enable
the integration itself; a first contribution may also require approval in Netlify.
Keep the production domain on GitHub Pages and do not assign it to Netlify.

All non-preview contexts are skipped by the ignore rule. The build script also
rejects non-preview contexts, including build hooks that bypass the ignore rule.
Every PR is built, including changes to shared inputs outside `website/` such as
`docs/`, `specs/`, `.specify/`, `catalog/`, and `pipeline/`.

To test the same build locally without deploying anything:

```sh
npm --prefix website ci --no-audit --no-fund
CONTEXT=deploy-preview DEPLOY_PRIME_URL=http://localhost:3000 \
  bash pipeline/build-netlify-preview.sh
npm --prefix website run serve -- --host 127.0.0.1 --port 3000
```

The refresh step may update derived docs in the checkout, so use a clean worktree.
For a linked Netlify project, `netlify build --context deploy-preview` can also
exercise Netlify's build orchestration; set `DEPLOY_PRIME_URL` for local testing.
Neither local build command publishes a site.

## Markdown and documentation discovery

Every build runs `scripts/generate-markdown-docs.cjs` after Docusaurus. It extracts
rendered article content from published pages and writes a `.md` counterpart at
each canonical route (for example, `/docs/home.md`). This includes guides,
specifications, and constitution pages, using their published slugs rather than
source filenames. Navigation and page controls are omitted; tables, code blocks,
and rendered MDX content are preserved. Mermaid diagrams also expose a collapsible
source block so their definitions survive static exports. Links to other published docs point to
their Markdown counterparts, and image URLs are absolute.

Each docs page offers **View Markdown** and **Documentation index** links.
`llms.txt` indexes the generated Markdown, and `llms-full.txt` bundles it. The
build rejects duplicate routes and missing or empty Markdown targets. Run
`npm --prefix website run test:markdown` for route, content, and base-path tests.

These are static files supported by both GitHub Pages and Netlify. Request the
explicit `.md` URL; `Accept: text/markdown` on an HTML URL does not switch formats.
AFDocs may still report this hosting limitation or HTML navigation overhead.
The production audit uses the canonical HTTPS URL to avoid treating HTTPS links
as external to an HTTP audit origin.
