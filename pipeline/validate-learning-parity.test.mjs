import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import test from 'node:test';
import {validateLearningParity} from './validate-learning-parity.mjs';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'traderx-learning-parity-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const write = (name, text) => {
    const target = path.join(root, name);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.writeFileSync(target, text);
  };
  const states = [{id: '001-base', previous: []}, {id: '002-child', previous: ['001-base'], status: 'planned'}];
  write('catalog/state-catalog.json', JSON.stringify({states}));
  write('specs/README.md', '## Portal Feature Packs\n\n- `003-portal`\n\n## References\n');
  for (const id of ['001-base', '002-child', '003-portal']) write(`specs/${id}/spec.md`, '# Spec\n');
  for (const {id} of states) write(`docs/learning/state-${id}.md`, '---\ntitle: "Guide"\n---\n');
  write('website/sidebars.js', "['learning/state-001-base', 'learning/state-002-child']");
  write('docs/learning-paths/index.md', 'S001_base["Base"]\nS002_child["Child"]\nS001_base -.-> S002_child\n');
  write('docs/learning/index.md', '001-base\n002-child\n');
  write('catalog/learning-paths.yaml', 'stateCatalog:\n  - id: 001-base\n  - id: 002-child\n');
  return {root, write};
}

test('accepts planned states with guides and explicitly classified portal packs', t => {
  const {root} = fixture(t);
  assert.deepEqual(validateLearningParity(root), {failures: [], states: 2, portalPacks: 1});
});

test('rejects a new pack omitted from both classifications', t => {
  const {root, write} = fixture(t);
  write('specs/004-new-capability/spec.md', '# New state');
  assert.match(validateLearningParity(root).failures.join('\n'), /Unclassified feature pack 004-new-capability/);
});

test('rejects omission of a planned state guide', t => {
  const {root} = fixture(t);
  fs.unlinkSync(path.join(root, 'docs/learning/state-002-child.md'));
  assert.match(validateLearningParity(root).failures.join('\n'), /Missing learning guide.*002-child/);
});

for (const [name, file, content, message] of [
  ['sidebar', 'website/sidebars.js', "['learning/state-001-base']", /Missing learning sidebar entry: 002-child/],
  ['graph node despite a table mention', 'docs/learning-paths/index.md', 'S001_base["Base"]\nS001_base -.-> S002_child\n| 002-child |', /Missing visual learning path node: 002-child/],
  ['parent edge despite both nodes', 'docs/learning-paths/index.md', 'S001_base["Base"]\nS002_child["Child"]', /Missing visual learning path edge: 001-base → 002-child/],
  ['learning index', 'docs/learning/index.md', '001-base', /Missing learning index entry: 002-child/],
  ['learning catalog', 'catalog/learning-paths.yaml', 'stateCatalog:\n  - id: 001-base', /Missing learning catalog entry: 002-child/],
]) {
  test(`rejects missing ${name}`, t => {
    const {root, write} = fixture(t);
    write(file, content);
    assert.match(validateLearningParity(root).failures.join('\n'), message);
  });
}
