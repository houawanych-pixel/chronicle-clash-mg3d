'use strict';
// Two clients against one family server: they must always agree, and the
// server must hold up to races, resends, out-of-order events and restarts.
//   node --test server/family/test/
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createServer } = require('../server');

const BASE_CFG = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8'));
const DAY = 86400;

async function start(file, cfgOver = {}) {
  const { server } = createServer({ dataFile: file, config: Object.assign({}, BASE_CFG, cfgOver), adminToken: 'admin-secret', testClock: true });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const url = `http://127.0.0.1:${server.address().port}`;
  return { server, url, close: () => new Promise(r => server.close(r)) };
}

function client(url, name, token) {
  let n = 0;
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = 'Bearer ' + token;
  return {
    name,
    id: () => `${name}:${++n}:${Math.random().toString(36).slice(2, 8)}`,
    async send(events) {
      const r = await fetch(url + '/v1/events', { method: 'POST', headers, body: JSON.stringify({ events }) });
      return r.json();
    },
    async state(since) {
      const r = await fetch(url + '/v1/state' + (since !== undefined ? '?since=' + since : ''));
      return r.json();
    },
    async advance(seconds) {
      await fetch(url + '/v1/test/clock', { method: 'POST', headers, body: JSON.stringify({ advance_seconds: seconds }) });
    },
  };
}

const view = s => JSON.stringify({ npcs: s.npcs, families: s.families, relationships: s.relationships, pregnancies: s.pregnancies, rev: s.rev });

test('two clients share one living village', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'famsrv-'));
  const file = path.join(dir, 'world.json');
  let srv = await start(file, { pregnancy_chance: 1.0 });
  let A = client(srv.url, 'A');
  let B = client(srv.url, 'B');

  // Seeded from the game's village cast; both see the same thing.
  const s0a = await A.state(), s0b = await B.state();
  assert.strictEqual(Object.keys(s0a.npcs).length, 12);
  assert.strictEqual(view(s0a), view(s0b));
  assert.strictEqual(s0a.relationships['ml_ada|ml_rolf'].kind, 'married');

  // Race: two suitors propose to Lia at the same moment; Lia accepts both
  // at the same moment. Exactly one partnership can exist.
  await Promise.all([
    A.send([{ id: A.id(), type: 'propose_partner', args: { from: 'sq_finn', to: 'sq_lia' } }]),
    B.send([{ id: B.id(), type: 'propose_partner', args: { from: 'sq_bram', to: 'sq_lia' } }]),
  ]);
  const [ra, rb] = await Promise.all([
    A.send([{ id: A.id(), type: 'accept_partner', args: { from: 'sq_finn', to: 'sq_lia' } }]),
    B.send([{ id: B.id(), type: 'accept_partner', args: { from: 'sq_bram', to: 'sq_lia' } }]),
  ]);
  const oks = [ra.results[0].ok, rb.results[0].ok];
  assert.strictEqual(oks.filter(Boolean).length, 1, 'only one partnership may form: ' + JSON.stringify([ra, rb]));
  const loser = ra.results[0].ok ? rb.results[0] : ra.results[0];
  assert.ok(['already_partnered', 'no_proposal'].includes(loser.error), loser.error);

  // Out of order: an accept that arrives before its proposal is refused,
  // then succeeds when resent after the proposal lands.
  const acc = { id: B.id(), type: 'accept_partner', args: { from: 'ml_kit', to: 'ml_nell' } };
  assert.strictEqual((await B.send([acc])).results[0].error, 'no_proposal');
  await A.send([{ id: A.id(), type: 'propose_partner', args: { from: 'ml_kit', to: 'ml_nell' } }]);
  assert.strictEqual((await B.send([acc])).results[0].ok, true);

  // Race for a baby: both clients report the same couple's home visit at
  // once (different ids). Only one visit counts; only one pregnancy exists.
  const [va, vb] = await Promise.all([
    A.send([{ id: A.id(), type: 'home_visit', at: 9999999999, args: { a: 'ml_ada', b: 'ml_rolf' } }]),
    B.send([{ id: B.id(), type: 'home_visit', args: { a: 'ml_ada', b: 'ml_rolf' } }]),
  ]);
  const visits = [va.results[0], vb.results[0]];
  assert.strictEqual(visits.filter(r => r.ok).length, 1, JSON.stringify(visits));
  assert.strictEqual(visits.filter(r => r.error === 'visit_cooldown').length, 1);
  let s = await A.state();
  const pregs = Object.values(s.pregnancies);
  assert.strictEqual(pregs.length, 1);
  assert.ok(Math.abs(pregs[0].conceived_at - s.server_time) < 5, 'server time is used, not the client\'s');

  // A resend after a "disconnect" changes nothing.
  const once = { id: A.id(), type: 'remember', args: { npc_id: 'sq_tam', text: 'The knight helped with the well.' } };
  const r1 = await A.send([once]);
  const r2 = await A.send([once]);
  assert.strictEqual(r2.results[0].duplicate, true);
  assert.strictEqual(r2.rev, r1.rev);

  // Clients can't order births, add people or kill anyone.
  const pid = pregs[0].pregnancy_id;
  const forbidden = await B.send([
    { id: B.id(), type: 'birth', args: { pregnancy_id: pid } },
    { id: B.id(), type: 'register_npc', args: { npc: { npc_id: 'fake' } } },
    { id: B.id(), type: 'death', args: { npc_id: 'sq_tam' } },
  ]);
  assert.ok(forbidden.results.every(r => r.error === 'not_allowed'));

  // Time passes on the server: one birth, the same baby for both clients.
  await A.advance(3 * DAY + 60);
  const [sa, sb] = await Promise.all([A.state(), B.state()]);
  assert.strictEqual(view(sa), view(sb));
  const babies = Object.values(sa.npcs).filter(r => r.parent_ids.includes('ml_ada'));
  assert.strictEqual(babies.length, 1);
  assert.deepStrictEqual(babies[0].parent_ids, ['ml_ada', 'ml_rolf']);
  const babyId = babies[0].npc_id;
  const unchanged = await B.state(sa.rev);
  assert.strictEqual(unchanged.unchanged, true, 'reading again creates nothing new');

  // Aging continues while nobody is connected; both see the same stage.
  await A.advance(20 * DAY);
  const [ga, gb] = await Promise.all([A.state(), B.state()]);
  assert.strictEqual(ga.npcs[babyId].life_stage, 'early_walker');
  assert.strictEqual(view(ga), view(gb));
  assert.deepStrictEqual(ga.npcs[babyId].stage_log.map(x => x.stage), ['newborn', 'crawling_infant', 'early_walker']);

  // Restart: a new server process on the same file keeps everything.
  const before = view(ga);
  await srv.close();
  srv = await start(file, { pregnancy_chance: 1.0 });
  A = client(srv.url, 'A2');
  B = client(srv.url, 'B2');
  const after = await A.state();
  assert.strictEqual(view(after), before);
  assert.strictEqual((await B.send([once])).results[0].duplicate, true, 'ids applied before the restart are still known');

  // The dead can't be recruited; children can't take combat jobs.
  const adminC = client(srv.url, 'admin', 'admin-secret');
  assert.ok((await adminC.send([{ id: 'adm-death-1', type: 'death', args: { npc_id: 'sq_mara', cause: 'fever' } }])).results[0].ok);
  const rec = await A.send([{ id: A.id(), type: 'recruit', args: { npc_id: 'sq_mara', by: 'hero' } }, { id: A.id(), type: 'set_job', args: { npc_id: babyId, job: 'guard' } }]);
  assert.strictEqual(rec.results[0].error, 'not_alive');
  assert.strictEqual(rec.results[1].error, 'child_combat_job');
  assert.ok((await B.state()).npcs.sq_mara, 'the dead stay in the records');
  await srv.close();
});

test('population limit holds under concurrent visits', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'famsrv-'));
  const srv = await start(path.join(dir, 'world.json'), { pregnancy_chance: 1.0, max_population: 13 });
  const adminC = client(srv.url, 'admin', 'admin-secret');
  const A = client(srv.url, 'A'), B = client(srv.url, 'B');
  // A second couple (the cast is 12; limit 13 leaves room for one pregnancy).
  await adminC.send([{ id: 'reg-x', type: 'register_npc', args: { npc: { npc_id: 'x_jo', name: 'Jo', can_carry: true, home_id: 'square/home_finn' } } }]);
  const s0 = await A.state();
  assert.strictEqual(Object.keys(s0.npcs).length, 13);
  // Limit is already reached by the living population: nobody conceives.
  const r = await Promise.all([
    A.send([{ id: 'v-a', type: 'home_visit', args: { a: 'ml_ada', b: 'ml_rolf' } }]),
    B.send([{ id: 'v-b', type: 'home_visit', args: { a: 'ml_ada', b: 'ml_rolf' } }]),
  ]);
  const ok = r.map(x => x.results[0]).filter(x => x.ok);
  assert.strictEqual(ok.length, 1);
  assert.strictEqual(ok[0].conceived, false);
  assert.strictEqual(ok[0].conception_block, 'population_limit');
  assert.strictEqual(Object.keys((await B.state()).pregnancies).length, 0);
  await srv.close();
});
