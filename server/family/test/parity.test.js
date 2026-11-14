'use strict';
// The server rules must give exactly the game's results. Runs
// server/family/test/scenario.json through Godot (family_tests.gd --parity)
// and through rules.js, then compares state, per-op results and config.
//   GODOT=/path/to/godot node --test server/family/test/
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { Rules } = require('../rules');

const ROOT = path.join(__dirname, '..', '..', '..');
const GODOT = process.env.GODOT;

function canon(v) {
  if (Array.isArray(v)) return v.map(canon);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map(k => [k, canon(v[k])]));
  if (typeof v === 'number' && Number.isInteger(v)) return v;
  return v;
}

test('game rules and server rules agree on one scenario', { skip: !GODOT && 'set GODOT to run' }, () => {
  const out = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'fam-')), 'godot.json');
  execFileSync(GODOT, ['--headless', '--path', ROOT, 'res://scenes/systems/cc_family_test.tscn', '--',
    `--parity=res://server/family/test/scenario.json,${out}`], { stdio: 'pipe', timeout: 120000 });
  const g = JSON.parse(fs.readFileSync(out, 'utf8'));
  const sc = JSON.parse(fs.readFileSync(path.join(__dirname, 'scenario.json'), 'utf8'));
  const cfgFile = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8'));
  for (const k of Object.keys(g.config)) {
    const want = Array.isArray(g.config[k]) ? g.config[k] : g.config[k];
    assert.deepStrictEqual(cfgFile[k], want, `server config.json "${k}" differs from family_config.tres`);
  }
  const cfg = JSON.parse(JSON.stringify(cfgFile));
  const rules = new Rules(cfg, JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'seed_state.json'), 'utf8')));
  const results = [];
  for (const op of sc.ops) {
    if (op.op === 'cfg') cfg[op.key] = op.value;
    else if (op.op === 'apply') results.push(rules.apply(op.ev));
    else if (op.op === 'sync') results.push(rules.sync(op.now));
  }
  // JSON from Godot writes whole floats as e.g. 1000.0 -> 1000 after parse; compare canonically.
  assert.deepStrictEqual(canon(results), canon(g.results));
  assert.deepStrictEqual(canon(rules.state), canon(g.state));
  // The scenario must have exercised births, refusals and duplicates.
  assert.ok(Object.keys(rules.state.npcs).length >= 14);
  assert.ok(results.some(r => r && r.duplicate));
  assert.ok(results.some(r => r && r.error === 'duplicate_birth'));
});
