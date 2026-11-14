'use strict';
// Two real game clients (two headless Godot processes running
// scripts/cc/family/family_net.gd) against one family server at once.
//   GODOT=/path/to/godot npm test   (in server/family)
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { createServer } = require('../server');

const ROOT = path.join(__dirname, '..', '..', '..');
const GODOT = process.env.GODOT;
const canon = v => Array.isArray(v) ? v.map(canon) : (v && typeof v === 'object') ? Object.fromEntries(Object.keys(v).sort().map(k => [k, canon(v[k])])) : v;

function runClient(url, who, out) {
  return new Promise((resolve, reject) => {
    const p = spawn(GODOT, ['--headless', '--path', ROOT, 'res://scenes/systems/cc_family_test.tscn', '--', `--net-client=${url},${who},${out}`], { stdio: ['ignore', 'pipe', 'pipe'] });
    let log = '';
    p.stdout.on('data', d => { log += d; });
    p.stderr.on('data', d => { log += d; });
    const kill = setTimeout(() => p.kill('SIGKILL'), 90000);
    p.on('close', code => { clearTimeout(kill); code === 0 ? resolve(log) : reject(new Error(`client ${who} exit ${code}\n${log}`)); });
  });
}

test('two game clients at once agree with the server and with each other', { skip: !GODOT && 'set GODOT to run' }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'famgame-'));
  const cfg = Object.assign(JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8')), { pregnancy_chance: 1.0 });
  const { server } = createServer({ dataFile: path.join(dir, 'world.json'), config: cfg, adminToken: '' });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${server.address().port}`;
  const outA = path.join(dir, 'a.json'), outB = path.join(dir, 'b.json');
  await Promise.all([runClient(url, 'A', outA), runClient(url, 'B', outB)]);
  const a = JSON.parse(fs.readFileSync(outA, 'utf8'));
  const b = JSON.parse(fs.readFileSync(outB, 'utf8'));
  const s = await (await fetch(url + '/v1/state')).json();
  server.close();
  assert.ok(a.pulled && b.pulled, `pull failed: ${a.error} ${b.error}`);
  // The resent batch changed nothing: accepted events come back as
  // duplicates, refused ones (never recorded) are refused again.
  for (const c of [a, b]) {
    c.results[1].forEach((r, i) => {
      const first = c.results[0][i];
      assert.ok(first.ok ? r.duplicate === true : (!r.ok && r.error === first.error), JSON.stringify([first, r]));
    });
  }
  // Exactly one of the two suitors won Lia; exactly one visit and pregnancy.
  const accepts = [a.results[2][0], b.results[2][0]];
  assert.strictEqual(accepts.filter(r => r.ok).length, 1, JSON.stringify(accepts));
  const visits = [a.results[0][1], b.results[0][1]];
  assert.strictEqual(visits.filter(r => r.ok).length, 1, JSON.stringify(visits));
  assert.strictEqual(Object.keys(s.pregnancies).length, 1);
  // Both clients hold exactly the server's records (whoever pulled last saw the final state).
  const final = canon({ npcs: s.npcs, families: s.families, relationships: s.relationships, pregnancies: s.pregnancies });
  const latest = a.rev >= b.rev ? a : b;
  assert.strictEqual(latest.rev, s.rev);
  assert.deepStrictEqual(canon(latest.state), final);
  if (a.rev === b.rev) assert.deepStrictEqual(canon(a.state), canon(b.state));
});
