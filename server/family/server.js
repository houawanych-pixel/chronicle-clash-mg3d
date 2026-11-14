'use strict';
// Chronicle Clash family server (reference implementation, not deployed).
// The authority for the shared Living Village: identities, families, births,
// aging timestamps, locations, jobs, recruitment, memories and deaths.
//
//   node server/family/server.js            (PORT, FAMILY_DATA, FAMILY_ADMIN_TOKEN)
//
// Safeguards
// - One process owns one world file; every request runs through a single
//   queue, so two clients can never interleave half-applied changes.
// - Every event carries a client-made unique id; resending it (after a
//   disconnect or timeout) is answered with {duplicate: true} and changes nothing.
// - Time is the server's: client "at" values are replaced by server time, and
//   births and aging come only from sync() on the server clock.
// - Births can't be requested by clients at all; register_npc and death need
//   the admin token. Clients only send the player-facing events below.
// - No AI service key lives here or is sent to clients. Echo Vision chat keeps
//   using its own proxy (web/village_chat.js); this server never calls an AI.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Rules } = require('./rules');
const store = require('./store');

const CLIENT_TYPES = new Set(['propose_partner', 'accept_partner', 'end_partner', 'home_visit', 'set_location', 'set_job', 'remember', 'recruit']);
const ADMIN_TYPES = new Set(['register_npc', 'death']);
const MAX_BODY = 64 * 1024;
const MAX_EVENTS = 50;

function createServer(opts = {}) {
  const cfg = opts.config || JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
  const file = opts.dataFile || process.env.FAMILY_DATA || path.join(__dirname, 'data', 'world.json');
  const admin = opts.adminToken !== undefined ? opts.adminToken : (process.env.FAMILY_ADMIN_TOKEN || '');
  const testClock = opts.testClock || process.env.FAMILY_TEST_CLOCK === '1';
  let offset = 0;
  const now = () => Math.floor(Date.now() / 1000) + offset;
  // A brand-new world starts from the village cast exported by the game
  // (seed_state.json, made by family_tests.gd --export-seed).
  const seedFile = opts.seedFile || path.join(__dirname, 'seed_state.json');
  const fresh = !fs.existsSync(file) && fs.existsSync(seedFile);
  const rules = new Rules(cfg, fresh ? store.load(seedFile) : store.load(file));
  rules.sync(now());
  store.save(file, rules.state);

  let queue = Promise.resolve();
  const serial = fn => (queue = queue.then(fn, fn));

  function publicState(since) {
    const s = rules.state;
    if (since !== undefined && Number(since) === s.rev) return { rev: s.rev, unchanged: true, server_time: now() };
    return { rev: s.rev, server_time: now(), npcs: s.npcs, families: s.families, relationships: s.relationships, pregnancies: s.pregnancies };
  }

  function handleEvents(body, isAdmin) {
    const evs = Array.isArray(body.events) ? body.events : [];
    if (evs.length === 0 || evs.length > MAX_EVENTS) return [400, { error: 'events: send 1..' + MAX_EVENTS }];
    const t = now();
    rules.sync(t);
    const results = [];
    for (const ev of evs) {
      const type = String((ev && ev.type) || '');
      if (!(CLIENT_TYPES.has(type) || (isAdmin && ADMIN_TYPES.has(type)))) { results.push({ id: ev && ev.id, ok: false, error: 'not_allowed' }); continue; }
      const r = rules.apply({ id: ev.id, type, at: t, args: ev.args || {} });
      results.push(Object.assign({ id: ev.id }, r));
    }
    rules.sync(t);
    store.save(file, rules.state);
    return [200, { rev: rules.state.rev, server_time: t, results }];
  }

  const server = http.createServer((req, res) => {
    const send = (code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(obj)); };
    const url = new URL(req.url, 'http://x');
    const isAdmin = admin !== '' && req.headers.authorization === 'Bearer ' + admin;
    let size = 0;
    const chunks = [];
    req.on('data', c => { size += c.length; if (size > MAX_BODY) { send(413, { error: 'too_big' }); req.destroy(); } else chunks.push(c); });
    req.on('end', () => {
      if (res.writableEnded) return;
      let body = {};
      if (chunks.length) { try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch (e) { return send(400, { error: 'bad_json' }); } }
      serial(() => {
        if (req.method === 'GET' && url.pathname === '/health') return send(200, { ok: true, rev: rules.state.rev });
        if (req.method === 'GET' && url.pathname === '/v1/state') {
          rules.sync(now());
          store.save(file, rules.state);
          return send(200, publicState(url.searchParams.has('since') ? url.searchParams.get('since') : undefined));
        }
        if (req.method === 'POST' && url.pathname === '/v1/events') {
          const [code, obj] = handleEvents(body, isAdmin);
          return send(code, obj);
        }
        if (req.method === 'GET' && url.pathname === '/v1/can_visit') {
          return send(200, { why: rules.visitBlock(url.searchParams.get('a') || '', url.searchParams.get('b') || '', now()) });
        }
        if (testClock && req.method === 'POST' && url.pathname === '/v1/test/clock') {
          offset += Math.trunc(Number(body.advance_seconds || 0));
          rules.sync(now());
          store.save(file, rules.state);
          return send(200, { server_time: now() });
        }
        return send(404, { error: 'not_found' });
      });
    });
  });
  return { server, rules, now };
}

if (require.main === module) {
  const { server } = createServer();
  const port = Number(process.env.PORT || 8787);
  server.listen(port, () => console.log('family server on :' + port));
}

module.exports = { createServer };
