// Upstream-pristine guard: the project README (and the repository root) belong to
// FINOS. Estate marketing — hackathon banners, judge-routing blockquotes, third-party
// score tables — must never be committed into upstream surfaces by a contribution.
// This guard fails the build if that ever happens again.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..', '..', '..');
const README = readFileSync(join(REPO_ROOT, 'README.md'), 'utf8');

// Tokens that mark estate marketing rather than project documentation.
// The 016 spec pack MAY reference synapticchain.xyz as the live reference
// receiver (documentation of an adapter target — reviewed); the project README
// may not reference it at all.
const FORBIDDEN_IN_README = [
  /colosseum/i,
  /synapticchain\.xyz/i,
  /JUDGES_FLOW/i,
  /Verification record/i,
  /zenodo\.org/i,
  /synaptics-?lab/i,
];

test('upstream README is pristine — no estate marketing tokens', () => {
  for (const pattern of FORBIDDEN_IN_README) {
    assert.doesNotMatch(README, pattern,
      `README.md contains estate marketing token ${pattern} — this surface belongs to FINOS; keep that content in the contributor's own repositories`);
  }
});

test('README does not open with an embedded image banner', () => {
  assert.doesNotMatch(README, /^\s*<p[^>]*>\s*<img/m,
    'README.md must not open with a centered image banner');
});

test('no banner image files at the repository root', () => {
  const banners = readdirSync(REPO_ROOT).filter((n) => n.endsWith('.svg'));
  assert.deepEqual(banners, [],
    `repository root must hold no image banners, found: ${banners.join(', ')}`);
});