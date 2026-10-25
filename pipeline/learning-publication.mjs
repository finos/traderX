// Shared by publication, tests, and the built-site gate; inputs remain canonical.
export function learningIndex(states, sourceRevision, baseUrl = '/') {
  const base = '/' + baseUrl.split('/').filter(Boolean).join('/');
  const route = suffix => (base === '/' ? '' : base) + suffix;
  return {
    version: 1,
    sourceRevision,
    schema: route('/learning/contract.schema.json'),
    protocol: route('/docs/learning/how-to-learn.md'),
    states: states.map(state => ({
      id: state.id,
      title: state.title,
      status: state.status,
      previous: state.previous ?? [],
      dottedParents: state.dottedParents ?? [],
      next: states.filter(s => s.previous?.includes(state.id)).map(s => s.id),
      source: `${state.featurePack}/learning-contract.json`,
      contract: route(`/learning/contracts/${state.id}.json`),
      guide: route(`/docs/learning/state-${state.id}`),
      markdown: route(`/docs/learning/state-${state.id}.md`),
    })),
  };
}

import fs from 'node:fs';
import path from 'node:path';
import {isDeepStrictEqual} from 'node:util';

export function validatePublishedLearning(root, build, sourceRevision, baseUrl = '/') {
  const errors = [];
  const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
  const {states} = read(path.join(root, 'catalog/state-catalog.json'));
  const expected = learningIndex(states, sourceRevision, baseUrl);
  const base = '/' + baseUrl.split('/').filter(Boolean).join('/');
  const local = url => path.join(build, base === '/' ? url : url.slice(base.length));
  const check = (file, value, label) => {
    try { if (!isDeepStrictEqual(read(file), value)) errors.push(`${label}: published JSON differs from canonical source`); }
    catch { errors.push(`${label}: missing or invalid published JSON`); }
  };
  check(path.join(build, 'learning/index.json'), expected, 'agent index');
  check(local(expected.schema), read(path.join(root, 'docs/.schema/learning-contract.schema.json')), 'contract schema');
  if (!fs.existsSync(local(expected.protocol))) errors.push('agent index: missing Markdown protocol');
  for (const entry of expected.states) {
    const c = read(path.join(root, entry.source));
    check(local(entry.contract), c, entry.id);
    if (!fs.existsSync(local(entry.guide) + '.html') && !fs.existsSync(path.join(local(entry.guide), 'index.html'))) errors.push(`${entry.id}: missing published HTML guide`);
    try {
      const markdown = fs.readFileSync(local(entry.markdown), 'utf8').replace(/\s+/g, ' ');
      for (const prompt of c.coaching) {
        for (const text of [prompt.diagnosticQuestion, prompt.predictionPrompt, ...prompt.hints, prompt.misconception, prompt.evidenceToRequest]) {
          if (!markdown.includes(text.replace(/\s+/g, ' '))) errors.push(`${entry.id}: Markdown omits coaching content: ${text.slice(0, 50)}`);
        }
      }
    } catch { errors.push(`${entry.id}: missing published Markdown guide`); }
  }
  return errors;
}
