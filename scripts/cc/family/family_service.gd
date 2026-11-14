extends RefCounted
## The family simulation's rules. Every change is an event:
##   {"id": unique string, "type": ..., "at": unix seconds, "args": {...}}
## apply() validates the whole event first and changes nothing if it fails,
## so a rejected event leaves no half-written state. An event id that was
## already applied returns {"ok": true, "duplicate": true} and does nothing,
## so a client can safely resend after a disconnect.
##
## The same rules run on the server (server/family/rules.js). The server is the
## authority online; this copy keeps the village working offline and lets the
## game check an action before asking the server. The simulation decides
## pregnancy, birth, aging, death and recruitment. Echo Vision only proposes
## (see family_context.gd) and never calls apply() directly.
const Profile = preload("res://scripts/cc/family/family_profile.gd")
const Growth = preload("res://scripts/cc/family/child_growth.gd")
const Preg = preload("res://scripts/cc/family/pregnancy_service.gd")
const CONFIG_PATH: String = "res://data/cc/family/family_config.tres"
const NAMES_PATH: String = "res://data/cc/family/names.json"

signal born(baby_id: String)
signal stage_changed(npc_id: String, stage: String, at: int)
signal applied(ev: Dictionary, result: Dictionary)

var cfg: Resource
var state: Dictionary
var names: Dictionary = {}

func _init(config: Resource = null) -> void:
	cfg = config if config != null else load(CONFIG_PATH)
	state = Profile.empty_state()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		names = parsed

# ---------------------------------------------------------------- queries

func npc(id: String) -> Dictionary:
	return state.npcs.get(id, {})

func family(id: String) -> Dictionary:
	return state.families.get(id, {})

func relationship(a: String, b: String) -> Dictionary:
	return state.relationships.get(Profile.pair_key(a, b), {})

func living_count() -> int:
	var n: int = 0
	for r: Dictionary in state.npcs.values():
		if bool(r.alive):
			n += 1
	return n

func children_of(parent_id: String) -> Array:
	var out: Array = []
	for r: Dictionary in state.npcs.values():
		if parent_id in r.parent_ids:
			out.append(r)
	return out

func partner_of(id: String) -> String:
	for rel: Dictionary in state.relationships.values():
		if str(rel.kind) in ["partners", "married"] and (rel.a == id or rel.b == id):
			return str(rel.b) if rel.a == id else str(rel.a)
	return ""

func is_adult(r: Dictionary) -> bool:
	return str(r.get("life_stage", "")) == "adult"

func related(a: Dictionary, b: Dictionary) -> bool:
	var ida: String = str(a.npc_id)
	var idb: String = str(b.npc_id)
	if ida in b.parent_ids or idb in a.parent_ids:
		return true
	for p: Variant in a.parent_ids:
		if p in b.parent_ids:
			return true                               # siblings / half-siblings
		var gp: Dictionary = npc(str(p))
		if not gp.is_empty() and idb in gp.parent_ids:
			return true                               # aunt/uncle
	for p: Variant in b.parent_ids:
		var gp: Dictionary = npc(str(p))
		if not gp.is_empty() and (ida in gp.parent_ids):
			return true                               # aunt/uncle the other way
		for gpp: Variant in gp.get("parent_ids", []):
			if str(gpp) == ida:
				return true                           # grandparent
	for p: Variant in a.parent_ids:
		var gp: Dictionary = npc(str(p))
		for gpp: Variant in gp.get("parent_ids", []):
			if str(gpp) == idb:
				return true
	return false

## Why two people can't become partners, or "" if they can.
func partner_block(a_id: String, b_id: String) -> String:
	if a_id == b_id:
		return "same_person"
	var a: Dictionary = npc(a_id)
	var b: Dictionary = npc(b_id)
	if a.is_empty() or b.is_empty():
		return "unknown_npc"
	if not bool(a.alive) or not bool(b.alive):
		return "not_alive"
	if not is_adult(a) or not is_adult(b):
		return "not_adult"
	if related(a, b):
		return "related"
	var pa: String = partner_of(a_id)
	var pb: String = partner_of(b_id)
	if (pa != "" and pa != b_id) or (pb != "" and pb != a_id):
		return "already_partnered"
	return ""

## Why a couple can't have a home visit now, or "" if they can.
func visit_block(a_id: String, b_id: String, at: int) -> String:
	var why: String = partner_block(a_id, b_id)
	if why != "":
		return why
	var rel: Dictionary = relationship(a_id, b_id)
	if rel.is_empty() or not (str(rel.kind) in ["partners", "married"]):
		return "not_partners"
	if not bool(rel.consent.get(a_id, false)) or not bool(rel.consent.get(b_id, false)):
		return "no_consent"
	if int(rel.last_visit_at) >= 0 and at - int(rel.last_visit_at) < int(cfg.visit_cooldown_seconds):
		return "visit_cooldown"
	return ""

## Whether a completed home visit is allowed to start a pregnancy. Returns
## the carrier id, or "" with the reason in `why`.
func conception_block(a_id: String, b_id: String, at: int) -> String:
	if not cfg.allow_pregnancy:
		return "pregnancy_disabled"
	var carrier: Dictionary = Preg.carrier_of(npc(a_id), npc(b_id))
	if carrier.is_empty():
		return "no_carrier"
	if not Preg.active_for(state, str(carrier.npc_id)).is_empty():
		return "already_pregnant"
	for id: String in [a_id, b_id]:
		var lb: int = int(npc(id).get("last_birth_at", -1))
		if lb >= 0 and at - lb < int(cfg.birth_cooldown_days * cfg.seconds_per_day):
			return "birth_cooldown"
	if living_count() + Preg.active_count(state) >= cfg.max_population:
		return "population_limit"
	var fam: Dictionary = family(family_of_pair(a_id, b_id))
	if not fam.is_empty() and fam.child_ids.size() >= cfg.max_children_per_family:
		return "family_full"
	return ""

func family_of_pair(a_id: String, b_id: String) -> String:
	for f: Dictionary in state.families.values():
		if a_id in f.parent_ids and b_id in f.parent_ids:
			return str(f.family_id)
	return ""

# ---------------------------------------------------------------- events

func fail(code: String) -> Dictionary:
	return {"ok": false, "error": code}

func apply(ev: Dictionary) -> Dictionary:
	var id: String = str(ev.get("id", ""))
	if id == "":
		return fail("missing_id")
	if state.applied.has(id):
		return {"ok": true, "duplicate": true, "rev": int(state.applied[id])}
	var at: int = int(ev.get("at", 0))
	var args: Dictionary = ev.get("args", {})
	var r: Dictionary
	match str(ev.get("type", "")):
		"register_npc": r = ev_register(args)
		"propose_partner": r = ev_propose(args, at)
		"accept_partner": r = ev_accept(args, at)
		"end_partner": r = ev_end_partner(args, at)
		"home_visit": r = ev_home_visit(id, args, at)
		"birth": r = ev_birth(args, at)
		"death": r = ev_death(args, at)
		"recruit": r = ev_recruit(args, at)
		"set_job": r = ev_set_job(args)
		"set_location": r = ev_set_location(args)
		"remember": r = ev_remember(args, at)
		_: r = fail("unknown_type")
	if not bool(r.get("ok", false)):
		return r
	state.rev = int(state.rev) + 1
	state.applied[id] = state.rev
	state.applied_order.append(id)
	while state.applied_order.size() > cfg.applied_event_keep:
		state.applied.erase(state.applied_order.pop_front())
	r["rev"] = state.rev
	applied.emit(ev, r)
	return r

func ev_register(a: Dictionary) -> Dictionary:
	var rec: Dictionary = a.get("npc", {})
	var id: String = str(rec.get("npc_id", ""))
	if id == "":
		return fail("missing_id")
	if state.npcs.has(id):
		return fail("npc_exists")
	var full: Dictionary = Profile.new_npc(id, str(rec.get("name", id)))
	full.merge(rec, true)
	state.npcs[id] = full
	return {"ok": true, "npc_id": id}

func ev_propose(a: Dictionary, at: int) -> Dictionary:
	var from: String = str(a.get("from", ""))
	var to: String = str(a.get("to", ""))
	var why: String = partner_block(from, to)
	if why != "":
		return fail(why)
	var key: String = Profile.pair_key(from, to)
	var rel: Dictionary = state.relationships.get(key, Profile.new_relationship(from, to))
	if str(rel.kind) in ["partners", "married"]:
		return fail("already_partners")
	rel.kind = "proposed"
	rel.consent = {from: true}
	rel.since = at
	state.relationships[key] = rel
	return {"ok": true}

func ev_accept(a: Dictionary, at: int) -> Dictionary:
	var from: String = str(a.get("from", ""))       # who proposed
	var to: String = str(a.get("to", ""))           # who is agreeing now
	var why: String = partner_block(from, to)
	if why != "":
		return fail(why)
	var rel: Dictionary = relationship(from, to)
	if rel.is_empty() or str(rel.kind) != "proposed" or not bool(rel.consent.get(from, false)):
		return fail("no_proposal")
	rel.consent[to] = true
	rel.kind = "partners"
	rel.since = at
	var fid: String = family_of_pair(from, to)
	if fid == "":
		fid = "fam_" + Profile.pair_key(from, to).replace("|", "__")
		var home: String = str(npc(from).home_id)
		var fam: Dictionary = Profile.new_family(fid, [from, to], home)
		state.families[fid] = fam
	var f: Dictionary = state.families[fid]
	if not (rel.key in f.partner_relationships):
		f.partner_relationships.append(rel.key)
	f.family_relationship_history.append({"at": at, "kind": "partnered", "ids": [from, to]})
	for id: String in [from, to]:
		if str(npc(id).family_id) == "":
			npc(id).family_id = fid
	return {"ok": true, "family_id": fid}

func ev_end_partner(a: Dictionary, at: int) -> Dictionary:
	var rel: Dictionary = relationship(str(a.get("a", "")), str(a.get("b", "")))
	if rel.is_empty() or not (str(rel.kind) in ["partners", "married", "proposed"]):
		return fail("not_partners")
	rel.kind = "ended"
	rel.consent = {}
	var fid: String = family_of_pair(str(rel.a), str(rel.b))
	if fid != "":
		state.families[fid].family_relationship_history.append({"at": at, "kind": "separated", "ids": [rel.a, rel.b]})
	return {"ok": true}

func ev_home_visit(event_id: String, a: Dictionary, at: int) -> Dictionary:
	var ia: String = str(a.get("a", ""))
	var ib: String = str(a.get("b", ""))
	var why: String = visit_block(ia, ib, at)
	if why != "":
		return fail(why)
	var rel: Dictionary = relationship(ia, ib)
	rel.last_visit_at = at
	var out: Dictionary = {"ok": true, "conceived": false, "pregnancy_id": ""}
	var no: String = conception_block(ia, ib, at)
	out["conception_block"] = no
	if no == "" and Preg.rolls_conception(event_id, cfg.pregnancy_chance):
		var carrier: Dictionary = Preg.carrier_of(npc(ia), npc(ib))
		var cid: String = str(carrier.npc_id)
		var partner: String = ib if cid == ia else ia
		var p: Dictionary = Preg.new_pregnancy(event_id, cid, partner, family_of_pair(ia, ib), at, cfg)
		state.pregnancies[p.pregnancy_id] = p
		out.conceived = true
		out.pregnancy_id = p.pregnancy_id
	return out

func ev_birth(a: Dictionary, at: int) -> Dictionary:
	var pid: String = str(a.get("pregnancy_id", ""))
	var p: Dictionary = state.pregnancies.get(pid, {})
	if p.is_empty():
		return fail("unknown_pregnancy")
	if str(p.status) != "active":
		return fail("duplicate_birth")
	if at < int(p.due_at):
		return fail("not_due")
	var baby_id: String = Preg.baby_id_for(pid)
	if state.npcs.has(baby_id):
		return fail("duplicate_birth")
	var carrier: Dictionary = npc(str(p.carrier_id))
	var partner: Dictionary = npc(str(p.partner_id))
	if carrier.is_empty() or not bool(carrier.alive):
		return fail("carrier_unavailable")
	var due: int = int(p.due_at)
	var female: bool = Profile.unit("sex:" + pid) < 0.5
	var pool: Array = names.get("f" if female else "m", ["Ash"])
	var nm: String = str(pool[Profile.fnv("name:" + pid) % pool.size()])
	var traits: Array = names.get("traits", ["curious"])
	var t1: String = str(traits[Profile.fnv("t1:" + pid) % traits.size()])
	var t2: String = str(traits[Profile.fnv("t2:" + pid) % traits.size()])
	var baby: Dictionary = Profile.new_npc(baby_id, nm)
	baby.birth_timestamp = due
	baby.life_stage = cfg.stage_names[0]
	baby.parent_ids = [str(p.carrier_id), str(p.partner_id)]
	baby.family_id = str(p.family_id)
	baby.personality = t1 if t1 == t2 else "%s and %s" % [t1, t2]
	baby.sex = "f" if female else "m"
	baby.can_carry = female
	baby.appearance_traits = {
		"tint_from": [carrier.get("appearance_traits", {}).get("tint", ""), partner.get("appearance_traits", {}).get("tint", "")],
		"model_from": carrier.get("appearance_traits", {}).get("model", 0) if Profile.unit("look:" + pid) < 0.5 else partner.get("appearance_traits", {}).get("model", 0),
	}
	var fam: Dictionary = family(str(p.family_id))
	baby.home_id = str(fam.get("home_id", carrier.home_id))
	baby.location = Profile.home_block(str(baby.home_id))
	baby.stage_log = [{"stage": cfg.stage_names[0], "at": due}]
	state.npcs[baby_id] = baby
	p.status = "born"
	p.baby_id = baby_id
	for id: String in baby.parent_ids:
		var par: Dictionary = npc(id)
		if not par.is_empty():
			par.last_birth_at = due
			add_memory(par, due, "%s, our baby, was born." % nm)
	if not fam.is_empty():
		fam.child_ids.append(baby_id)
		fam.family_relationship_history.append({"at": due, "kind": "birth", "ids": [baby_id]})
	born.emit(baby_id)
	return {"ok": true, "baby_id": baby_id}

func ev_death(a: Dictionary, at: int) -> Dictionary:
	var r: Dictionary = npc(str(a.get("npc_id", "")))
	if r.is_empty():
		return fail("unknown_npc")
	if not bool(r.alive):
		return fail("already_dead")
	r.alive = false
	r.health_state = "dead"
	r.died_at = at
	r.recruited_by = ""
	for rel: Dictionary in state.relationships.values():
		if (rel.a == r.npc_id or rel.b == r.npc_id) and str(rel.kind) in ["partners", "married", "proposed"]:
			rel.kind = "widowed"
	var fam: Dictionary = family(str(r.family_id))
	if not fam.is_empty():
		fam.family_relationship_history.append({"at": at, "kind": "death", "ids": [r.npc_id], "cause": str(a.get("cause", ""))})
	return {"ok": true}

func ev_recruit(a: Dictionary, at: int) -> Dictionary:
	var r: Dictionary = npc(str(a.get("npc_id", "")))
	if r.is_empty():
		return fail("unknown_npc")
	if not bool(r.alive):
		return fail("not_alive")
	if not is_adult(r):
		return fail("not_adult")
	if str(r.recruited_by) != "":
		return fail("already_recruited")
	r.recruited_by = str(a.get("by", "hero"))
	add_memory(r, at, "Joined %s on the road." % str(a.get("by_name", "the knight")))
	return {"ok": true}

func ev_set_job(a: Dictionary) -> Dictionary:
	var r: Dictionary = npc(str(a.get("npc_id", "")))
	var job: String = str(a.get("job", ""))
	if r.is_empty():
		return fail("unknown_npc")
	if not is_adult(r) and job in cfg.combat_jobs:
		return fail("child_combat_job")
	r.current_job = job
	return {"ok": true}

func ev_set_location(a: Dictionary) -> Dictionary:
	var r: Dictionary = npc(str(a.get("npc_id", "")))
	if r.is_empty():
		return fail("unknown_npc")
	if a.has("block"):
		r.location = str(a.block)
	if a.has("activity"):
		r.current_activity = str(a.activity)
	return {"ok": true}

func ev_remember(a: Dictionary, at: int) -> Dictionary:
	var r: Dictionary = npc(str(a.get("npc_id", "")))
	if r.is_empty():
		return fail("unknown_npc")
	var text: String = str(a.get("text", "")).strip_edges()
	if text == "":
		return fail("empty")
	add_memory(r, at, text)
	return {"ok": true}

# ---------------------------------------------------------------- memory

func add_memory(r: Dictionary, at: int, text: String) -> void:
	var t: String = text.replace("\n", " ").strip_edges().left(cfg.memory_entry_chars)
	var mem: Array = r.get("memories", [])
	mem.append({"at": at, "text": t})
	while mem.size() > cfg.memory_max_entries:
		mem.pop_front()
	r["memories"] = mem
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(mem.size() - 1, -1, -1):
		var s: String = str(mem[i].text)
		if (" ".join(parts) + " " + s).length() > cfg.memory_summary_chars:
			break
		parts.insert(0, s)
	r["memory_summary"] = " ".join(parts)

# ---------------------------------------------------------------- time

## Advance everything to `now`: births that came due (each as its own
## idempotent event, born at its due time) and aging. Safe to call any
## number of times; safe after the game was closed for weeks.
func sync(now: int) -> Dictionary:
	var births: Array = []
	var due: Array = []
	for p: Dictionary in state.pregnancies.values():
		if str(p.status) == "active" and int(p.due_at) <= now:
			due.append(p)
	due.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.due_at) < int(y.due_at))
	for p: Dictionary in due:
		var r: Dictionary = apply({"id": "birth:" + str(p.pregnancy_id), "type": "birth", "at": int(p.due_at), "args": {"pregnancy_id": p.pregnancy_id}})
		if bool(r.get("ok", false)) and not r.has("duplicate"):
			births.append(r.baby_id)
	var transitions: Array = []
	for r: Dictionary in state.npcs.values():
		for tr: Dictionary in Growth.advance(r, now, cfg):
			transitions.append({"npc_id": r.npc_id, "stage": tr.stage, "at": tr.at})
			if tr.stage == "early_walker":
				for pid: Variant in r.parent_ids:
					var par: Dictionary = npc(str(pid))
					if not par.is_empty():
						add_memory(par, int(tr.at), "%s took first steps." % r.name)
			stage_changed.emit(str(r.npc_id), str(tr.stage), int(tr.at))
	return {"births": births, "transitions": transitions}
