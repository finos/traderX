import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {validateContract, renderContract} from './learning-contract.mjs';
const schema = JSON.parse(fs.readFileSync(new URL('../docs/.schema/learning-contract.schema.json', import.meta.url)));
const {states} = JSON.parse(fs.readFileSync(new URL('../catalog/state-catalog.json', import.meta.url)));
const read = s => JSON.parse(fs.readFileSync(new URL(`../${s.featurePack}/learning-contract.json`, import.meta.url)));
const baseline = states[0], child = states[1];
const validate = (c, s = child, catalog = states) => validateContract(c, s, catalog, schema);
test('all existing states, including foundation, satisfy schema and semantics', () => {
  for (const state of states) assert.deepEqual(validate(read(state), state), [], state.id);
});
for (const [name, mutate, pattern] of [
  ['missing coaching', c => delete c.coaching, /coaching/],
  ['missing coaching objective', c => c.coaching[0].objectiveIds = ['trace-increment'], /coaching: uncovered/],
  ['invalid coaching objective', c => c.coaching[0].objectiveIds = ['unknown'], /coaching: dangling/],
  ['missing graduated hints', c => c.coaching[0].hints = ['Only one hint with sufficient text.'], /hints/],
  ['missing purpose', c => delete c.purpose, /purpose/],
  ['placeholder purpose', c => c.purpose = 'TODO', /purpose/],
  ['repeated placeholders', c => c.purpose = 'TODO TBD TODO TBD TODO TBD', /purpose/],
  ['missing predecessor transition', c => c.transitions = [], /transition/],
  ['incorrect predecessor', c => c.transitions[0].from = '999-unknown', /predecessor/],
  ['uncovered objective', c => c.objectives.push({id:'uncovered',outcome:'Explain a new behavior with concrete evidence.'}), /uncovered/],
  ['broken objective reference', c => c.walkthrough[0].objectiveIds = ['missing'], /dangling/],
  ['incomplete implemented guidance', c => c.walkthrough[0].expected = '', /expected/],
  ['implemented exercise unavailable', c => c.walkthrough[0].availability = 'unavailable', /available/],
  ['missing assessment guidance', c => delete c.assessments[0].guidance, /guidance/],
  ['duplicate objective IDs', c => c.objectives.push(c.objectives[0]), /duplicate/],
]) test(name, () => {const c = read(child); mutate(c); assert.match(validate(c).join('\n'), pattern);});
test('baseline cannot invent a predecessor', () => {
  const c = read(baseline); c.transitions = read(child).transitions;
  assert.match(validate(c, baseline).join('\n'), /transition/);
});
test('multiple parents require each transition, combined and alternative routes supported', () => {
  const state = {...child, previous:[baseline.id, states[2].id]};
  const c = read(child);
  assert.match(validate(c, state).join('\n'), /transition/);
  c.transitions.push({...c.transitions[0], from:states[2].id});
  assert.deepEqual(validate(c, state), []);
  c.entryMode = 'alternative';
  assert.deepEqual(validate(c, state), []);
  assert.match(renderContract(c, state), /Choose an entry route/);
});
test('planned states expose intended work but cannot claim runnable exercises', () => {
  const state = {...child, status:'planned', generation:{mode:'planned'}};
  const c = read(child);
  assert.match(validate(c, state).join('\n'), /unavailable/);
  c.walkthrough.forEach(w => w.availability = 'unavailable');
  assert.deepEqual(validate(c, state), []);
  assert.match(renderContract(c, state), /runtime exercises are unavailable/);
});

import os from 'node:os';
import path from 'node:path';
import {validateLearningContracts} from './validate-learning-contract.mjs';
test('repository gate rejects missing contracts, stale presentation and broken supporting pages', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'learning-contract-test-'));
  t.after(() => fs.rmSync(root, {recursive:true, force:true}));
  const write = (name, value) => {const file = path.join(root, name); fs.mkdirSync(path.dirname(file), {recursive:true}); fs.writeFileSync(file, value);};
  const c = read(baseline);
  write('catalog/state-catalog.json', JSON.stringify({states:[baseline]}));
  write('docs/.schema/learning-contract.schema.json', JSON.stringify(schema));
  write(`${baseline.featurePack}/learning-contract.json`, JSON.stringify(c));
  write(`docs/learning/state-${baseline.id}.md`, renderContract(c, baseline));
  write('docs/learning/index.md', `/docs/learning/how-to-learn [guide](/docs/learning/state-${baseline.id})`);
  write('docs/learning-paths/index.md', `/docs/learning/how-to-learn click S${baseline.id.replaceAll('-', '_')} href "/docs/learning/state-${baseline.id}"`);
  for (const file of ['website/docusaurus.config.js', 'website/src/components/homepage/homepageData.js', 'website/src/components/homepage/Hero.jsx']) write(file, 'Learning Guide /docs/learning');
  for (const reference of c.walkthrough.flatMap(w => w.references)) write(`${baseline.featurePack}/${reference.split('/').slice(3).join('/')}.md`, '# Reference');
  assert.deepEqual(validateLearningContracts(root), []);
  fs.unlinkSync(path.join(root, baseline.featurePack, 'quickstart.md'));
  assert.match(validateLearningContracts(root).join('\n'), /broken supporting reference/);
  write(`docs/learning/state-${baseline.id}.md`, '# Outdated guide');
  assert.match(validateLearningContracts(root).join('\n'), /current contract/);
  fs.unlinkSync(path.join(root, baseline.featurePack, 'learning-contract.json'));
  assert.match(validateLearningContracts(root).join('\n'), /learning-contract.json/);
});

import {learningIndex, validatePublishedLearning} from './learning-publication.mjs';
test('agent publication preserves lineage, base paths and source revision', () => {
  const index = learningIndex(states, 'test-revision', '/traderX/');
  const c3 = index.states.find(s => s.id.startsWith('012'));
  assert.deepEqual(c3.next, states.filter(s => s.previous.includes(c3.id)).map(s => s.id));
  assert.equal(index.sourceRevision, 'test-revision');
  assert.equal(index.schema, '/traderX/learning/contract.schema.json');
  assert.equal(index.states[0].markdown, '/traderX/docs/learning/state-' + baseline.id + '.md');
});
test('agent publication rejects drift, missing destinations and omitted Markdown coaching', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'learning-publication-test-'));
  t.after(() => fs.rmSync(root, {recursive:true, force:true}));
  const write = (name, value) => {const file = path.join(root, name); fs.mkdirSync(path.dirname(file), {recursive:true}); fs.writeFileSync(file, value);};
  const c = read(baseline), index = learningIndex([baseline], 'revision', '/traderX/');
  const stem = 'build/docs/learning/state-' + baseline.id;
  write('catalog/state-catalog.json', JSON.stringify({states:[baseline]}));
  write('docs/.schema/learning-contract.schema.json', JSON.stringify(schema));
  write(`${baseline.featurePack}/learning-contract.json`, JSON.stringify(c));
  write('build/learning/index.json', JSON.stringify(index));
  write('build/learning/contract.schema.json', JSON.stringify(schema));
  write(`build/learning/contracts/${baseline.id}.json`, JSON.stringify(c));
  write('build/docs/learning/how-to-learn.md', '# Protocol');
  write(stem + '.html', '<h1>Lesson</h1>');
  write(stem + '.md', renderContract(c, baseline));
  const validate = () => validatePublishedLearning(root, path.join(root, 'build'), 'revision', '/traderX/');
  assert.deepEqual(validate(), []);
  index.sourceRevision = 'stale';
  write('build/learning/index.json', JSON.stringify(index));
  assert.match(validate().join('\n'), /agent index.*differs/);
  write(`build/learning/contracts/${baseline.id}.json`, '{}');
  assert.match(validate().join('\n'), /001.*differs/);
  write(stem + '.md', '# Incomplete export');
  assert.match(validate().join('\n'), /Markdown omits coaching/);
  fs.unlinkSync(path.join(root, stem + '.html'));
  assert.match(validate().join('\n'), /missing published HTML/);
});
