'use strict';
// Family rules, server side. A line-for-line port of
// scripts/cc/family/family_service.gd (+ child_growth.gd, pregnancy_service.gd,
// family_profile.gd). test/parity.test.js runs one scenario through both and
// checks the results are identical, so the two can't drift apart unnoticed.
//
// Pure functions over a plain state object; no I/O, no clock of its own.
const fs = require('fs');
const path = require('path');

const SCHEMA = 1;
const NAMES = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'cc', 'family', 'names.json'), 'utf8'));

function fnv(s) {
  let h = 2166136261;
  for (const b of Buffer.from(String(s), 'utf8')) {
    h ^= b;
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}
const unit = s => fnv(s) / 4294967296;
const pairKey = (a, b) => (a < b ? a + '|' + b : b + '|' + a);
const homeBlock = h => (h.includes('/') ? h.split('/')[0] : '');

function newNpc(id, name) {
  return {
    npc_id: id, name, birth_timestamp: -1, life_stage: 'adult', parent_ids: [], family_id: '',
    personality: '', appearance_traits: {}, current_job: '', current_activity: '', alive: true,
    health_state: 'well', memory_summary: '', memories: [], stage_log: [], sex: '', can_carry: false,
    home_id: '', location: '', established: false, age_locked: false, recruited_by: '', died_at: -1, last_birth_at: -1,
  };
}
function newFamily(id, parents, home) {
  return { family_id: id, parent_ids: parents.slice(), child_ids: [], partner_relationships: [], home_id: home, family_relationship_history: [] };
}
function newRelationship(a, b) {
  return { key: pairKey(a, b), a: a < b ? a : b, b: a < b ? b : a, kind: 'acquaintance', consent: {}, since: -1, last_visit_at: -1, established: false, notes: [] };
}
function emptyState() {
  return { schema: SCHEMA, world_id: 'cc_village', rev: 0, npcs: {}, families: {}, relationships: {}, pregnancies: {}, applied: {}, applied_order: [] };
}

class Rules {
  constructor(cfg, state) {
    this.cfg = cfg;
    this.state = state || emptyState();
  }
  stageIndex(s) { return this.cfg.stage_names.indexOf(s); }
  npc(id) { return this.state.npcs[id] || null; }
  family(id) { return this.state.families[id] || null; }
  relationship(a, b) { return this.state.relationships[pairKey(a, b)] || null; }
  livingCount() { return Object.values(this.state.npcs).filter(r => r.alive).length; }
  childrenOf(id) { return Object.values(this.state.npcs).filter(r => r.parent_ids.includes(id)); }
  partnerOf(id) {
    for (const rel of Object.values(this.state.relationships)) {
      if ((rel.kind === 'partners' || rel.kind === 'married') && (rel.a === id || rel.b === id)) return rel.a === id ? rel.b : rel.a;
    }
    return '';
  }
  isAdult(r) { return r.life_stage === 'adult'; }
  related(a, b) {
    const ida = a.npc_id, idb = b.npc_id;
    if (b.parent_ids.includes(ida) || a.parent_ids.includes(idb)) return true;
    for (const p of a.parent_ids) {
      if (b.parent_ids.includes(p)) return true;
      const gp = this.npc(p);
      if (gp && gp.parent_ids.includes(idb)) return true;
    }
    for (const p of b.parent_ids) {
      const gp = this.npc(p);
      if (gp && gp.parent_ids.includes(ida)) return true;
      for (const gpp of (gp ? gp.parent_ids : [])) if (gpp === ida) return true;
    }
    for (const p of a.parent_ids) {
      const gp = this.npc(p);
      for (const gpp of (gp ? gp.parent_ids : [])) if (gpp === idb) return true;
    }
    return false;
  }
  partnerBlock(aId, bId) {
    if (aId === bId) return 'same_person';
    const a = this.npc(aId), b = this.npc(bId);
    if (!a || !b) return 'unknown_npc';
    if (!a.alive || !b.alive) return 'not_alive';
    if (!this.isAdult(a) || !this.isAdult(b)) return 'not_adult';
    if (this.related(a, b)) return 'related';
    const pa = this.partnerOf(aId), pb = this.partnerOf(bId);
    if ((pa !== '' && pa !== bId) || (pb !== '' && pb !== aId)) return 'already_partnered';
    return '';
  }
  visitBlock(aId, bId, at) {
    const why = this.partnerBlock(aId, bId);
    if (why) return why;
    const rel = this.relationship(aId, bId);
    if (!rel || !(rel.kind === 'partners' || rel.kind === 'married')) return 'not_partners';
    if (!rel.consent[aId] || !rel.consent[bId]) return 'no_consent';
    if (rel.last_visit_at >= 0 && at - rel.last_visit_at < Math.trunc(this.cfg.visit_cooldown_seconds)) return 'visit_cooldown';
    return '';
  }
  carrierOf(a, b) { return a.can_carry ? a : b.can_carry ? b : null; }
  activeFor(id) { return Object.values(this.state.pregnancies).find(p => p.status === 'active' && p.carrier_id === id) || null; }
  activeCount() { return Object.values(this.state.pregnancies).filter(p => p.status === 'active').length; }
  familyOfPair(a, b) {
    for (const f of Object.values(this.state.families)) if (f.parent_ids.includes(a) && f.parent_ids.includes(b)) return f.family_id;
    return '';
  }
  conceptionBlock(aId, bId, at) {
    const c = this.cfg;
    if (!c.allow_pregnancy) return 'pregnancy_disabled';
    const carrier = this.carrierOf(this.npc(aId), this.npc(bId));
    if (!carrier) return 'no_carrier';
    if (this.activeFor(carrier.npc_id)) return 'already_pregnant';
    for (const id of [aId, bId]) {
      const lb = this.npc(id).last_birth_at;
      if (lb >= 0 && at - lb < Math.trunc(c.birth_cooldown_days * c.seconds_per_day)) return 'birth_cooldown';
    }
    if (this.livingCount() + this.activeCount() >= c.max_population) return 'population_limit';
    const fam = this.family(this.familyOfPair(aId, bId));
    if (fam && fam.child_ids.length >= c.max_children_per_family) return 'family_full';
    return '';
  }

  apply(ev) {
    const id = String(ev.id || '');
    if (!id) return fail('missing_id');
    if (Object.prototype.hasOwnProperty.call(this.state.applied, id)) return { ok: true, duplicate: true, rev: this.state.applied[id] };
    const at = Math.trunc(Number(ev.at || 0));
    const a = ev.args || {};
    let r;
    switch (String(ev.type || '')) {
      case 'register_npc': r = this.evRegister(a); break;
      case 'propose_partner': r = this.evPropose(a, at); break;
      case 'accept_partner': r = this.evAccept(a, at); break;
      case 'end_partner': r = this.evEndPartner(a, at); break;
      case 'home_visit': r = this.evHomeVisit(id, a, at); break;
      case 'birth': r = this.evBirth(a, at); break;
      case 'death': r = this.evDeath(a, at); break;
      case 'recruit': r = this.evRecruit(a, at); break;
      case 'set_job': r = this.evSetJob(a); break;
      case 'set_location': r = this.evSetLocation(a); break;
      case 'remember': r = this.evRemember(a, at); break;
      default: r = fail('unknown_type');
    }
    if (!r.ok) return r;
    this.state.rev += 1;
    this.state.applied[id] = this.state.rev;
    this.state.applied_order.push(id);
    while (this.state.applied_order.length > this.cfg.applied_event_keep) delete this.state.applied[this.state.applied_order.shift()];
    r.rev = this.state.rev;
    return r;
  }

  evRegister(a) {
    const rec = a.npc || {};
    const id = String(rec.npc_id || '');
    if (!id) return fail('missing_id');
    if (this.state.npcs[id]) return fail('npc_exists');
    this.state.npcs[id] = Object.assign(newNpc(id, String(rec.name || id)), JSON.parse(JSON.stringify(rec)));
    return { ok: true, npc_id: id };
  }
  evPropose(a, at) {
    const from = String(a.from || ''), to = String(a.to || '');
    const why = this.partnerBlock(from, to);
    if (why) return fail(why);
    const key = pairKey(from, to);
    const rel = this.state.relationships[key] || newRelationship(from, to);
    if (rel.kind === 'partners' || rel.kind === 'married') return fail('already_partners');
    rel.kind = 'proposed';
    rel.consent = { [from]: true };
    rel.since = at;
    this.state.relationships[key] = rel;
    return { ok: true };
  }
  evAccept(a, at) {
    const from = String(a.from || ''), to = String(a.to || '');
    const why = this.partnerBlock(from, to);
    if (why) return fail(why);
    const rel = this.relationship(from, to);
    if (!rel || rel.kind !== 'proposed' || !rel.consent[from]) return fail('no_proposal');
    rel.consent[to] = true;
    rel.kind = 'partners';
    rel.since = at;
    let fid = this.familyOfPair(from, to);
    if (!fid) {
      fid = 'fam_' + pairKey(from, to).replace('|', '__');
      this.state.families[fid] = newFamily(fid, [from, to], String(this.npc(from).home_id));
    }
    const f = this.state.families[fid];
    if (!f.partner_relationships.includes(rel.key)) f.partner_relationships.push(rel.key);
    f.family_relationship_history.push({ at, kind: 'partnered', ids: [from, to] });
    for (const id of [from, to]) if (this.npc(id).family_id === '') this.npc(id).family_id = fid;
    return { ok: true, family_id: fid };
  }
  evEndPartner(a, at) {
    const rel = this.relationship(String(a.a || ''), String(a.b || ''));
    if (!rel || !['partners', 'married', 'proposed'].includes(rel.kind)) return fail('not_partners');
    rel.kind = 'ended';
    rel.consent = {};
    const fid = this.familyOfPair(rel.a, rel.b);
    if (fid) this.state.families[fid].family_relationship_history.push({ at, kind: 'separated', ids: [rel.a, rel.b] });
    return { ok: true };
  }
  evHomeVisit(eventId, a, at) {
    const ia = String(a.a || ''), ib = String(a.b || '');
    const why = this.visitBlock(ia, ib, at);
    if (why) return fail(why);
    this.relationship(ia, ib).last_visit_at = at;
    const out = { ok: true, conceived: false, pregnancy_id: '' };
    const no = this.conceptionBlock(ia, ib, at);
    out.conception_block = no;
    if (!no && unit('conceive:' + eventId) < this.cfg.pregnancy_chance) {
      const carrier = this.carrierOf(this.npc(ia), this.npc(ib));
      const cid = carrier.npc_id;
      const p = {
        pregnancy_id: 'preg_' + eventId, carrier_id: cid, partner_id: cid === ia ? ib : ia,
        family_id: this.familyOfPair(ia, ib), conceived_at: at,
        due_at: at + Math.trunc(this.cfg.pregnancy_days * this.cfg.seconds_per_day), status: 'active', baby_id: '',
      };
      this.state.pregnancies[p.pregnancy_id] = p;
      out.conceived = true;
      out.pregnancy_id = p.pregnancy_id;
    }
    return out;
  }
  evBirth(a, at) {
    const pid = String(a.pregnancy_id || '');
    const p = this.state.pregnancies[pid];
    if (!p) return fail('unknown_pregnancy');
    if (p.status !== 'active') return fail('duplicate_birth');
    if (at < p.due_at) return fail('not_due');
    const babyId = 'npc_' + pid;
    if (this.state.npcs[babyId]) return fail('duplicate_birth');
    const carrier = this.npc(p.carrier_id), partner = this.npc(p.partner_id);
    if (!carrier || !carrier.alive) return fail('carrier_unavailable');
    const due = p.due_at;
    const female = unit('sex:' + pid) < 0.5;
    const pool = NAMES[female ? 'f' : 'm'];
    const nm = pool[fnv('name:' + pid) % pool.length];
    const tr = NAMES.traits;
    const t1 = tr[fnv('t1:' + pid) % tr.length], t2 = tr[fnv('t2:' + pid) % tr.length];
    const baby = newNpc(babyId, nm);
    const at1 = (carrier.appearance_traits || {}), at2 = ((partner || {}).appearance_traits || {});
    Object.assign(baby, {
      birth_timestamp: due, life_stage: this.cfg.stage_names[0], parent_ids: [p.carrier_id, p.partner_id], family_id: p.family_id,
      personality: t1 === t2 ? t1 : `${t1} and ${t2}`, sex: female ? 'f' : 'm', can_carry: female,
      appearance_traits: { tint_from: [at1.tint !== undefined ? at1.tint : '', at2.tint !== undefined ? at2.tint : ''], model_from: unit('look:' + pid) < 0.5 ? (at1.model !== undefined ? at1.model : 0) : (at2.model !== undefined ? at2.model : 0) },
    });
    const fam = this.family(p.family_id);
    baby.home_id = String(fam ? fam.home_id : carrier.home_id);
    baby.location = homeBlock(baby.home_id);
    baby.stage_log = [{ stage: this.cfg.stage_names[0], at: due }];
    this.state.npcs[babyId] = baby;
    p.status = 'born';
    p.baby_id = babyId;
    for (const id of baby.parent_ids) {
      const par = this.npc(id);
      if (par) { par.last_birth_at = due; this.addMemory(par, due, `${nm}, our baby, was born.`); }
    }
    if (fam) {
      fam.child_ids.push(babyId);
      fam.family_relationship_history.push({ at: due, kind: 'birth', ids: [babyId] });
    }
    return { ok: true, baby_id: babyId };
  }
  evDeath(a, at) {
    const r = this.npc(String(a.npc_id || ''));
    if (!r) return fail('unknown_npc');
    if (!r.alive) return fail('already_dead');
    r.alive = false; r.health_state = 'dead'; r.died_at = at; r.recruited_by = '';
    for (const rel of Object.values(this.state.relationships)) {
      if ((rel.a === r.npc_id || rel.b === r.npc_id) && ['partners', 'married', 'proposed'].includes(rel.kind)) rel.kind = 'widowed';
    }
    const fam = this.family(r.family_id);
    if (fam) fam.family_relationship_history.push({ at, kind: 'death', ids: [r.npc_id], cause: String(a.cause || '') });
    return { ok: true };
  }
  evRecruit(a, at) {
    const r = this.npc(String(a.npc_id || ''));
    if (!r) return fail('unknown_npc');
    if (!r.alive) return fail('not_alive');
    if (!this.isAdult(r)) return fail('not_adult');
    if (r.recruited_by !== '') return fail('already_recruited');
    r.recruited_by = String(a.by || 'hero');
    this.addMemory(r, at, `Joined ${String(a.by_name || 'the knight')} on the road.`);
    return { ok: true };
  }
  evSetJob(a) {
    const r = this.npc(String(a.npc_id || ''));
    const job = String(a.job || '');
    if (!r) return fail('unknown_npc');
    if (!this.isAdult(r) && this.cfg.combat_jobs.includes(job)) return fail('child_combat_job');
    r.current_job = job;
    return { ok: true };
  }
  evSetLocation(a) {
    const r = this.npc(String(a.npc_id || ''));
    if (!r) return fail('unknown_npc');
    if ('block' in a) r.location = String(a.block);
    if ('activity' in a) r.current_activity = String(a.activity);
    return { ok: true };
  }
  evRemember(a, at) {
    const r = this.npc(String(a.npc_id || ''));
    if (!r) return fail('unknown_npc');
    const text = String(a.text || '').trim();
    if (!text) return fail('empty');
    this.addMemory(r, at, text);
    return { ok: true };
  }
  addMemory(r, at, text) {
    const c = this.cfg;
    const t = text.split('\n').join(' ').trim().slice(0, c.memory_entry_chars);
    const mem = r.memories || [];
    mem.push({ at, text: t });
    while (mem.length > c.memory_max_entries) mem.shift();
    r.memories = mem;
    const parts = [];
    for (let i = mem.length - 1; i >= 0; i--) {
      const s = mem[i].text;
      if ((parts.join(' ') + ' ' + s).length > c.memory_summary_chars) break;
      parts.unshift(s);
    }
    r.memory_summary = parts.join(' ');
  }

  // child_growth.gd
  ageDays(birth, now) { return birth < 0 ? -1 : Math.floor(Math.max(0, now - birth) / this.cfg.seconds_per_day); }
  stageIndexForDays(d) { let i = 0; this.cfg.stage_start_days.forEach((s, k) => { if (d >= s) i = k; }); return i; }
  advance(npc, now) {
    const out = [];
    const birth = npc.birth_timestamp;
    if (birth < 0 || npc.age_locked) return out;
    const log = npc.stage_log || [];
    const last = log.length ? this.stageIndex(log[log.length - 1].stage) : -1;
    let limit = now;
    if (!npc.alive && npc.died_at >= 0) limit = Math.min(now, npc.died_at);
    const target = Math.max(last, this.stageIndexForDays(this.ageDays(birth, limit)));
    for (let k = last + 1; k <= target; k++) {
      const tr = { stage: this.cfg.stage_names[k], at: birth + Math.trunc(this.cfg.stage_start_days[k] * this.cfg.seconds_per_day) };
      log.push(tr);
      out.push(tr);
    }
    npc.stage_log = log;
    if (target >= 0) npc.life_stage = this.cfg.stage_names[target];
    return out;
  }
  sync(now) {
    const births = [];
    const due = Object.values(this.state.pregnancies).filter(p => p.status === 'active' && p.due_at <= now).sort((x, y) => x.due_at - y.due_at);
    for (const p of due) {
      const r = this.apply({ id: 'birth:' + p.pregnancy_id, type: 'birth', at: p.due_at, args: { pregnancy_id: p.pregnancy_id } });
      if (r.ok && !r.duplicate) births.push(r.baby_id);
    }
    const transitions = [];
    for (const r of Object.values(this.state.npcs)) {
      for (const tr of this.advance(r, now)) {
        transitions.push({ npc_id: r.npc_id, stage: tr.stage, at: tr.at });
        if (tr.stage === 'early_walker') {
          for (const pid of r.parent_ids) {
            const par = this.npc(pid);
            if (par) this.addMemory(par, tr.at, `${r.name} took first steps.`);
          }
        }
      }
    }
    return { births, transitions };
  }
}
function fail(code) { return { ok: false, error: code }; }

module.exports = { Rules, emptyState, fnv, unit, pairKey, SCHEMA };
