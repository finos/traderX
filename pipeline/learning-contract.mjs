import fs from 'node:fs';
import path from 'node:path';

// Deliberately dependency-free: the root gates run before website dependencies exist.
// Implements the keywords used by our versioned JSON Schema; unknown keywords fail closed.
export function validateSchema(value, schema, at = '$') {
  const errors = [];
  const known = new Set(['$schema', 'title', 'type', 'required', 'additionalProperties', 'properties', 'items', 'minItems', 'minLength', 'pattern', 'enum', 'const']);
  for (const key of Object.keys(schema)) if (!known.has(key)) errors.push(`${at}: unsupported schema keyword ${key}`);
  const type = Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value;
  if (schema.type && type !== schema.type) return [...errors, `${at}: expected ${schema.type}`];
  if ('const' in schema && value !== schema.const) errors.push(`${at}: expected ${schema.const}`);
  if (schema.enum && !schema.enum.includes(value)) errors.push(`${at}: expected one of ${schema.enum.join(', ')}`);
  if (type === 'string') {
    if (schema.minLength && value.trim().length < schema.minLength) errors.push(`${at}: supply substantive content`);
    if (schema.pattern && !new RegExp(schema.pattern, 'i').test(value)) errors.push(`${at}: invalid or placeholder content`);
  }
  if (type === 'object') {
    for (const key of schema.required ?? []) if (!(key in value)) errors.push(`${at}.${key}: required`);
    for (const [key, child] of Object.entries(value)) {
      if (schema.properties?.[key]) errors.push(...validateSchema(child, schema.properties[key], `${at}.${key}`));
      else if (schema.additionalProperties === false) errors.push(`${at}.${key}: unknown field`);
    }
  }
  if (type === 'array') {
    if (schema.minItems && value.length < schema.minItems) errors.push(`${at}: at least ${schema.minItems} item(s) required`);
    if (schema.items) value.forEach((item, i) => errors.push(...validateSchema(item, schema.items, `${at}[${i}]`)));
  }
  return errors;
}

export function validateContract(contract, state, states, schema) {
  const errors = validateSchema(contract, schema);
  if (errors.length) return errors;
  if (contract.state !== state.id) errors.push('state: must match catalog ID');
  const parents = state.previous ?? [];
  const actual = contract.transitions.map(t => t.from);
  if (actual.length !== new Set(actual).size || actual.length !== parents.length || parents.some(p => !actual.includes(p))) errors.push('transitions: require exactly one transition per catalog predecessor');
  if (actual.some(p => !states.some(s => s.id === p))) errors.push('transitions: unknown predecessor');
  if ((!parents.length) !== (contract.entryMode === 'foundation')) errors.push('entryMode: baseline must be foundation; descendants must declare combined or alternative entry');
  for (const group of ['objectives', 'walkthrough']) if (new Set(contract[group].map(o => o.id)).size !== contract[group].length) errors.push(`${group}: duplicate stable identifiers`);
  const objectives = new Set(contract.objectives.map(o => o.id));
  for (const group of ['transitions', 'walkthrough', 'assessments']) {
    for (const item of contract[group]) for (const id of item.objectiveIds) if (!objectives.has(id)) errors.push(`${group}: dangling objective ${id}`);
  }
  for (const id of objectives) for (const group of ['walkthrough', 'assessments']) if (!contract[group].some(x => x.objectiveIds.includes(id))) errors.push(`${group}: uncovered objective ${id}`);
  const implemented = ['implemented', 'released'].includes(state.status) || state.generation?.mode === 'implemented';
  if (implemented && contract.walkthrough.some(w => w.availability !== 'available')) errors.push('walkthrough: implemented states require available exercises');
  if (!implemented && contract.walkthrough.some(w => w.availability !== 'unavailable')) errors.push('walkthrough: planned states must mark exercises unavailable');
  return errors;
}

export const readContract = (root, state) => JSON.parse(fs.readFileSync(path.join(root, state.featurePack, 'learning-contract.json'), 'utf8'));

export function renderContract(c, state) {
  const mapped = ids => ids.map(id => `\`${id}\``).join(', ');
  return `<!-- Generated from ${state.featurePack}/learning-contract.json; edit the source. -->

## ${c.title}

${c.purpose}

[How to learn with TraderX states](/docs/learning/how-to-learn)

**Maturity:** ${state.status}. ${c.walkthrough.every(w => w.availability === 'unavailable') ? 'Intended lesson: runtime exercises are unavailable.' : 'Run the exercises in a disposable local environment; use the quickstart for setup and cleanup.'}

### Starting point

${c.entryAssumptions}

${c.transitions.length ? `Entry route: **${c.entryMode}**. ${c.entryMode === 'combined' ? 'Bring the knowledge from every declared predecessor.' : 'Choose an entry route; each transition below describes the knowledge to add.'}\n\n` + c.transitions.map(t => `#### From ${t.from}

[Predecessor guide](/docs/learning/state-${t.from})

- **Carry forward:** ${t.carriesForward}
- **Why move:** ${t.motivation}
- **Add or revise:** ${t.increment}
- **Evidence to collect:** ${t.evidence}
- **Objectives:** ${mapped(t.objectiveIds)}`).join('\n\n') : 'This is the foundation. It has no predecessor; the entry assumptions above are the starting point.'}

| Before | After |
| --- | --- |
| ${c.before.replaceAll('|', '\\|')} | ${c.after.replaceAll('|', '\\|')} |

### Concepts before tools

${c.concepts.map(x => `- ${x}`).join('\n')}

**Runtime prerequisites:** ${c.runtimePrerequisites}

### Learning objectives

${c.objectives.map(o => `- **${o.id}:** ${o.outcome}`).join('\n')}

### Guided walkthrough

${c.walkthrough.map((w, i) => `#### ${i + 1}. ${w.id} (${w.availability})

Objectives: ${mapped(w.objectiveIds)}.

${w.action}

**Expected observation and meaning:** ${w.expected}

Supporting material: ${w.references.map((url, j) => `[${url.split('/').pop()}](${url})`).join(' · ')}.`).join('\n\n')}

### Demonstrate your understanding

${c.assessments.map(a => `**Question (${mapped(a.objectiveIds)}):** ${a.question}

**Assessment guidance:** ${a.guidance}`).join('\n\n')}

### Scope and limitations

${c.limitations.map(x => `- ${x}`).join('\n')}
`;
}
