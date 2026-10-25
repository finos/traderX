import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {load} from 'cheerio';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const build = path.join(root, 'website/build');
const {states} = JSON.parse(fs.readFileSync(path.join(root, 'catalog/state-catalog.json')));
const errors = [];
const base = (process.env.DOCUSAURUS_BASE_URL || '/').replace(/\/$/, '');
const files = fs.readdirSync(build, {recursive:true}).filter(f => f.endsWith('.html'));
const pages = new Map();
for (const file of files) {
  const route = '/' + file.replace(/\/index\.html$|^index\.html$|\.html$/g, '');
  pages.set(route.replace(/\/$/, '') || '/', load(fs.readFileSync(path.join(build, file), 'utf8')));
}
const normalize = href => {
  const url = new URL(href, 'https://portal.invalid');
  let route = decodeURI(url.pathname).replace(/\/$/, '') || '/';
  if (base && (route === base || route.startsWith(base + '/'))) route = route.slice(base.length) || '/';
  return {route, hash: decodeURIComponent(url.hash.slice(1))};
};
const hasLink = (from, to) => {
  const $ = pages.get(from);
  if (!$) {errors.push(`Missing built page ${from}`); return;}
  if (!$('a[href]').toArray().some(a => normalize($(a).attr('href')).route === to)) errors.push(`${from}: missing link to ${to}`);
  if (!pages.has(to)) errors.push(`${from}: unresolved built destination ${to}`);
};
hasLink('/', '/docs/learning');
hasLink('/docs/learning', '/docs/learning/how-to-learn');
hasLink('/docs/learning', '/docs/learning-paths');
for (const state of states) {
  const route = `/docs/learning/state-${state.id}`;
  const spec = `/specs/${state.id.slice(4)}`;
  hasLink('/docs/learning', route);
  hasLink(route, '/docs/learning'); // main navigation
  hasLink(route, spec);
  for (const related of [...state.previous, ...states.filter(s => s.previous.includes(state.id)).map(s => s.id)]) hasLink(route, `/docs/learning/state-${related}`);
  const contract = JSON.parse(fs.readFileSync(path.join(root, state.featurePack, 'learning-contract.json')));
  for (const reference of contract.walkthrough.flatMap(w => w.references)) hasLink(route, reference.split('#')[0]);
  const technicalPages = [...pages.keys()].filter(p => p === spec || p.startsWith(spec + '/'));
  if (!technicalPages.length) errors.push(`${state.id}: no technical pages built`);
  for (const technical of technicalPages) hasLink(technical, route);
  const $ = pages.get(route);
  if ($) {
    const normalizeText = text => text.replace(/\s+/g, ' ').trim();
    const visible = normalizeText($('article').text());
    for (const required of [contract.purpose, contract.entryAssumptions, ...contract.objectives.map(o => o.outcome), ...contract.walkthrough.flatMap(w => [w.action, w.expected]), ...contract.assessments.map(a => a.guidance)]) {
      if (!visible.includes(normalizeText(required))) errors.push(`${route}: built guide omits contract content: ${required.slice(0, 65)}`);
    }
    if ($('nav.pagination-nav a').length) errors.push(`${route}: remove sidebar-order pagination; use catalog relationships`);
  }
  if ($) for (const a of $('article a[href^="/"]').toArray()) {
    const {route: target, hash} = normalize($(a).attr('href'));
    const destination = pages.get(target);
    if (!destination && !fs.existsSync(path.join(build, target))) errors.push(`${route}: broken built link ${target}`);
    else if (destination && hash && !destination('[id]').toArray().some(n => destination(n).attr('id') === hash)) errors.push(`${route}: missing anchor ${target}#${hash}`);
  }
  // Mermaid is hydrated client-side; SSR contains its source, not an SVG anchor.
  const graph = pages.get('/docs/learning-paths');
  const node = 'S' + state.id.replaceAll('-', '_');
  if (!graph || !graph.text().includes(`click ${node} href "${base}${route}"`)) errors.push(`${state.id}: built diagram must target guide`);
}
if (errors.length) { errors.forEach(e => console.error(`[fail] ${e}`)); process.exit(1); }
console.log(`[ok] Built learning journeys: homepage, index, diagram, ${states.length} guides, every state technical page, and related-state links`);
