import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readContract, renderContract, validateContract} from './learning-contract.mjs';

export function validateLearningContracts(root) {
  const read = p => fs.readFileSync(path.join(root, p), 'utf8');
  const {states} = JSON.parse(read('catalog/state-catalog.json'));
  const schema = JSON.parse(read('docs/.schema/learning-contract.schema.json'));
  const errors = [];
  for (const state of states) {
    const fail = message => errors.push(`${state.id}: ${message}. Edit ${state.featurePack}/learning-contract.json and regenerate with node pipeline/generate-state-docs-from-catalog.mjs`);
    try {
      const contract = readContract(root, state);
      const failures = validateContract(contract, state, states, schema);
      failures.forEach(fail);
      if (failures.length) continue;
      const guide = read(`docs/learning/state-${state.id}.md`);
      if (!guide.includes(renderContract(contract, state))) fail('generated guide does not expose the current contract');
      for (const reference of contract.walkthrough.flatMap(w => w.references)) {
        const [slug, ...rest] = reference.slice('/specs/'.length).split('#')[0].split('/');
        const target = states.find(s => s.id.slice(4) === slug);
        const file = target && path.join(root, target.featurePack, (rest.join('/') || 'README') + '.md');
        if (!file || !fs.existsSync(file)) fail(`broken supporting reference ${reference}`);
      }
      for (const id of [...state.previous ?? [], ...states.filter(s => s.previous?.includes(state.id)).map(s => s.id)]) if (!guide.includes(`](/docs/learning/state-${id})`)) fail(`missing related guide link ${id}`);
      const graph = read('docs/learning-paths/index.md');
      const node = 'S' + state.id.replaceAll('-', '_');
      if (!graph.includes(`click ${node} href "/docs/learning/state-${state.id}"`)) fail('diagram must open learning guide');
      if (!read('docs/learning/index.md').includes(`](/docs/learning/state-${state.id})`)) fail('index must link to guide');
    } catch (error) { fail(error.message); }
  }
  for (const file of ['docs/learning/index.md', 'docs/learning-paths/index.md']) if (!read(file).includes('/docs/learning/how-to-learn')) errors.push(`${file}: link the learning introduction`);
  for (const file of ['website/docusaurus.config.js', 'website/src/components/homepage/homepageData.js', 'website/src/components/homepage/Hero.jsx']) if (!read(file).includes('Learning Guide') || !read(file).includes('/docs/learning')) errors.push(`${file}: expose the Learning Guide entry`);
  return errors;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const errors = validateLearningContracts(root);
  errors.forEach(e => console.error(`[fail] ${e}`));
  if (errors.length) process.exit(1);
  console.log('[ok] Every catalog state satisfies the incremental learning contract');
}
