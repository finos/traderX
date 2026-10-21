// Generated-tree purity proof (Spec 016, DovOps consolidated review item):
// "Preserve 014: settlement behavior must stay in the 016 overlay; prove
// clean 014 generation with a 014→016 comparison."
//
// The speckit generation model composes the Angular tree as
//
//     templates/web-front-end/angular  →  state frontend-overrides (cp -R)
//
// (see pipeline/render-state-014-fdc3-intent-interoperability.sh and
// ../generation-hook.md). This test replays that composition statically —
// the whole 001→015 chain carries no settlement vocabulary (asserted inline
// against every other state pack), so composing the upstream (bbd6408) web
// base with 014's frontend-overrides is a faithful stand-in for the generated
// 014 tree in everything this proof cares about.
//
// What it proves, in four gates:
//   Q0. no state pack other than 016 ships settlement vocabulary at all.
//   Q1. the upstream 014 composition (bbd6408 base + 014 frontend-overrides)
//       contains ZERO settlement vocabulary.
//   Q2. composing TODAY's templates tree with 014's overrides is
//       byte-identical under main/app to the upstream composition — the
//       shared templates tree carries no code delta that survives into
//       generated 014.
//   Q3. the 016 composition (same trees + the 016 pack frontend-overlay)
//       adds the settlement surface back exactly where the overlay says.
//
// Run: node tests/smoke/generated-tree-purity.test.mjs

import { strict as assert } from 'node:assert';
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { join, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const PACK_DIR = join(fileURLToPath(import.meta.url), '..', '..', '..');
const REPO_ROOT = join(PACK_DIR, '..', '..');
const TEMPLATES_WEB = join(REPO_ROOT, 'templates', 'web-front-end', 'angular');
const OVERLAY_014 = join(REPO_ROOT, 'specs', '014-fdc3-intent-interoperability', 'generation', 'frontend-overrides', 'web-front-end', 'angular');
const OVERLAY_016 = join(PACK_DIR, 'generation', 'frontend-overrides', 'web-front-end', 'angular');
const UPSTREAM_BASE = 'bbd6408';

const TMP_ROOT = join(tmpdir(), 'spec016-purity');

const SETTLEMENT_MARKER = /settlement|StartPayment|settleTrade|payment-instruction|synaptic\.settlementStatus/i;

let gates = 0;
function gate(name, fn) {
    return Promise.resolve()
        .then(fn)
        .then(() => { console.log(`[ok] ${name}`); gates += 1; })
        .catch((error) => { console.error(`[fail] ${name}: ${error.message}`); process.exitCode = 1; });
}

function listTree(root) {
    const out = [];
    const walk = (dir) => {
        if (!existsSync(dir)) return;
        for (const entry of readdirSync(dir, { withFileTypes: true })) {
            const path = join(dir, entry.name);
            if (entry.isDirectory()) walk(path);
            else out.push(relative(root, path));
        }
    };
    walk(root);
    return out;
}

// Composes a projected Angular tree: the web base first, then each overlay
// layered on top with the copy idiom the state renderers use
// (`cp -R "${dir}/." "${dest}/"`), run through bash so the projection is what
// the generation model actually does, not a re-implementation of it.
function compose(destination, base, ...overlays) {
    rmSync(destination, { recursive: true, force: true });
    mkdirSync(destination, { recursive: true });
    const q = (path) => `cp -R "${path}/." "${destination}/"`;
    execFileSync('bash', ['-c', ['set -euo pipefail', q(base), ...overlays.map(q)].join('\n')], { stdio: 'pipe' });
}
await gate('Q0: every other state pack (001–015) carries no settlement vocabulary in frontend overrides', async () => {
    const specsRoot = join(REPO_ROOT, 'specs');
    const offenders = [];
    for (const state of readdirSync(specsRoot, { withFileTypes: true })) {
        if (!state.isDirectory() || !/^\d/.test(state.name) || state.name.startsWith('016')) continue;
        const overrides = join(specsRoot, state.name, 'generation', 'frontend-overrides');
        if (!existsSync(overrides)) continue;
        for (const file of listTree(overrides)) {
            if (!/\.(ts|html)$/.test(file)) continue;
            const content = readFileSync(join(overrides, file), 'utf8');
            if (SETTLEMENT_MARKER.test(content)) offenders.push(`${state.name}: ${file}`);
        }
    }
    assert.deepEqual(offenders, [], 'no other state pack may ship settlement vocabulary');
});

await gate('Q1: upstream 014 composition (bbd6408 base + 014 overlays) is free of settlement vocabulary', async () => {
    const worktree = join(TMP_ROOT, 'upstream-base');
    rmSync(worktree, { recursive: true, force: true });
    mkdirSync(worktree, { recursive: true });
    // Only the upstream web tree matters here; extract it from the base commit
    // via git archive so the proof never depends on the working tree.
    const tarball = join(TMP_ROOT, 'upstream-web.tar');
    execFileSync('git', ['-C', REPO_ROOT, 'archive', UPSTREAM_BASE, '-o', tarball, '--', 'templates/web-front-end/angular'], { stdio: 'pipe' });
    execFileSync('tar', ['-xf', tarball, '-C', worktree], { stdio: 'pipe' });
    const upstreamBase = join(worktree, 'templates', 'web-front-end', 'angular');

    const composed = join(TMP_ROOT, 'composed-014-upstream');
    compose(composed, upstreamBase, OVERLAY_014);

    const offenders = [];
    for (const file of listTree(join(composed, 'main', 'app'))) {
        if (!/\.(ts|html)$/.test(file)) continue;
        const content = readFileSync(join(composed, 'main', 'app', file), 'utf8');
        if (SETTLEMENT_MARKER.test(content)) offenders.push(file);
    }
    assert.deepEqual(offenders, [], 'generated 014 must be free of settlement vocabulary');
});

await gate('Q2: templates HEAD composition under main/app is byte-identical to the upstream 014 composition', async () => {
    // Same composition run against TODAY's shared templates tree. Any 016
    // settlement delta that had drifted into templates and could survive into
    // a generated 014 tree would show up as a mismatch here.
    const composed = join(TMP_ROOT, 'composed-014-head');
    compose(composed, TEMPLATES_WEB, OVERLAY_014);
    const upstream = join(TMP_ROOT, 'composed-014-upstream');

    const headFiles = listTree(join(composed, 'main', 'app'));
    const upstreamFiles = listTree(join(upstream, 'main', 'app'));
    const problems = [];
    for (const file of upstreamFiles) {
        if (!headFiles.includes(file)) problems.push(`missing: ${file}`);
    }
    for (const file of headFiles) {
        if (!upstreamFiles.includes(file)) {
            problems.push(`templates-only file would reach generated 014: ${file}`);
            continue;
        }
        const a = readFileSync(join(composed, 'main', 'app', file));
        const b = readFileSync(join(upstream, 'main', 'app', file));
        if (!a.equals(b)) problems.push(`differs from upstream base: ${file}`);
    }
    assert.deepEqual(problems, [], '014 composition of templates must equal the upstream composition');
});

await gate('Q3: the 016 composition adds the settlement surface exactly where the 016 overlay says', async () => {
    const composed = join(TMP_ROOT, 'composed-016');
    compose(composed, TEMPLATES_WEB, OVERLAY_014, OVERLAY_016);

    const read = (rel) => readFileSync(join(composed, 'main', 'app', rel), 'utf8');
    const blotter = read('trade/trade-blotter/trade-blotter.component.ts');
    assert.match(blotter, /SETTLE \(BANKERX\)/, '016 blotter must gate the settle action');
    assert.match(blotter, /buildPaymentInstruction/, '016 blotter must map the cash leg');
    const interop = read('service/fdc3-interop.service.ts');
    assert.match(interop, /synaptic\.settlementStatus/, '016 interop must listen for status broadcasts');
    const position = read('service/position.service.ts');
    assert.match(position, /settlementsUrl/, '016 position service must carry the registry endpoint');
    assert.match(read('model/account.model.ts'), /name\?:/, '016 account model must expose the desk identifier');
    assert.match(read('model/trade.model.ts'), /price\?:/, '016 trade model must expose the fill price');
});

if (process.exitCode) {
    console.error('== RED');
} else {
    console.log(`== GREEN (${gates}/4 purity gates)`);
}

rmSync(TMP_ROOT, { recursive: true, force: true });