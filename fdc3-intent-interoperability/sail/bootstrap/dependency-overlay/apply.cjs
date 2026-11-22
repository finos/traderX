const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const target = process.argv[2];
const policy = JSON.parse(fs.readFileSync(path.join(__dirname, 'policy.json')));
const actual = execFileSync('git', ['-C', target, 'rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
if (actual !== policy.sourceCommit) throw new Error(`Sail dependency overlay requires ${policy.sourceCommit}; got ${actual}`);
for (const file of policy.files) fs.copyFileSync(path.join(__dirname, file), path.join(target, file));
