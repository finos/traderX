import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export function validateLearningParity(root) {
  const read = p => fs.readFileSync(path.join(root, p), 'utf8');
  const catalog = JSON.parse(read('catalog/state-catalog.json'));
  const ids = new Set(catalog.states.map(s => s.id));
  // Documentation-only packs are explicitly classified rather than silently ignored.
  const portalSection = read('specs/README.md').split('## Portal Feature Packs')[1]?.split('\n## ')[0] ?? '';
  const portalPacks = new Set([...portalSection.matchAll(/^- `([^`]+)`/gm)].map(m => m[1]));
  const failures = [];
  for (const pack of fs.readdirSync(path.join(root, 'specs'), {withFileTypes: true}).filter(p => p.isDirectory() && /^\d{3}-/.test(p.name)).map(p => p.name)) {
    if (!ids.has(pack) && !portalPacks.has(pack)) failures.push(`Unclassified feature pack ${pack}: add it to the state catalog or explicitly classify it as a portal feature.`);
  }
  const sidebar = read('website/sidebars.js');
  const graph = read('docs/learning-paths/index.md');
  const learningIndex = read('docs/learning/index.md');
  const learningCatalog = read('catalog/learning-paths.yaml');
  for (const state of catalog.states) {
    const id = state.id;
    const guide = `docs/learning/state-${id}.md`;
    if (!fs.existsSync(path.join(root, guide))) failures.push(`Missing learning guide: ${guide}`);
    if (!sidebar.includes(`learning/state-${id}`)) failures.push(`Missing learning sidebar entry: ${id}`);
    const node = 'S' + id.replaceAll('-', '_');
    if (!graph.includes(`${node}[`)) failures.push(`Missing visual learning path node: ${id}`);
    for (const parent of state.previous ?? []) {
      const parentNode = 'S' + parent.replaceAll('-', '_');
      if (!graph.includes(`${parentNode} --> ${node}`) && !graph.includes(`${parentNode} -.-> ${node}`)) failures.push(`Missing visual learning path edge: ${parent} → ${id}`);
    }
    if (!learningIndex.includes(id)) failures.push(`Missing learning index entry: ${id}`);
    if (!learningCatalog.includes(`id: ${id}`)) failures.push(`Missing learning catalog entry: ${id}`);
  }
  return {failures, states: ids.size, portalPacks: portalPacks.size};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const result = validateLearningParity(root);
  for (const failure of result.failures) console.error(`[fail] ${failure}`);
  if (result.failures.length) process.exit(1);
  console.log(`[ok] Learning parity: ${result.states} states and ${result.portalPacks} explicitly classified portal packs`);
}
