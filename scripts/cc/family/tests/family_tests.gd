extends Node
## Family module unit tests (no village scene needed). Run:
##   godot --headless res://scenes/systems/cc_family_test.tscn -- --family-test --quit-after-test
## Prints "FT PASS/FAIL name" lines and "FT RESULT n/m".
const Service = preload("res://scripts/cc/family/family_service.gd")
const Save = preload("res://scripts/cc/family/family_save.gd")
const Profile = preload("res://scripts/cc/family/family_profile.gd")
const Growth = preload("res://scripts/cc/family/child_growth.gd")
const Acts = preload("res://scripts/cc/family/family_activities.gd")
const Ctx = preload("res://scripts/cc/family/family_context.gd")
const Anim = preload("res://scripts/cc/family/child_anim.gd")
const VillageScript = preload("res://scripts/citadel/Village.gd")
const DAY: int = 86400
const T0: int = 1_800_000_000

var results: Array = []

func _ready() -> void:
	run.call_deferred()

func check(name: String, ok: bool, info: String = "") -> void:
	results.append(ok)
	print("FT %s %s%s" % ["PASS" if ok else "FAIL", name, "" if info == "" else "  (" + info + ")"])

func fresh(chance: float = 1.0) -> RefCounted:
	var cfg: Resource = load(Service.CONFIG_PATH).duplicate()
	cfg.pregnancy_chance = chance
	var s: RefCounted = Service.new(cfg)
	for ev: Dictionary in Save.seed_events(VillageScript.BLOCKS, T0):
		s.apply(ev)
	Save.seed_relationships(s.state, T0)
	return s

## A new adult couple from scratch (not the established cast).
func couple(s: RefCounted, a: String, b: String, at: int) -> void:
	for id: String in [a, b]:
		s.apply({"id": "reg:" + id, "type": "register_npc", "at": at, "args": {"npc": {"npc_id": id, "name": id, "can_carry": id == a, "home_id": "square/home_bram", "location": "square"}}})
	s.apply({"id": "p:" + a + b, "type": "propose_partner", "at": at, "args": {"from": a, "to": b}})
	s.apply({"id": "a:" + a + b, "type": "accept_partner", "at": at, "args": {"from": a, "to": b}})

func visit(s: RefCounted, a: String, b: String, at: int, id: String) -> Dictionary:
	return s.apply({"id": id, "type": "home_visit", "at": at, "args": {"a": a, "b": b}})

func canon(st: Dictionary) -> String:
	return JSON.stringify(Save.migrate(JSON.parse_string(JSON.stringify(st))), "", true)

## --export-seed=<path>: write the seeded starting state (time 0) for the server.
## --parity=<scenario.json>,<out.json>: run a scenario, write the final state.
func tool_modes() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--export-seed="):
			var st: RefCounted = Service.new(load(Service.CONFIG_PATH))
			for ev: Dictionary in Save.seed_events(VillageScript.BLOCKS, 0):
				st.apply(ev)
			Save.seed_relationships(st.state, 0)
			var f: FileAccess = FileAccess.open(arg.trim_prefix("--export-seed="), FileAccess.WRITE)
			f.store_string(JSON.stringify(st.state, "  ", true))
			f.close()
			print("FT seed exported")
			return true
		if arg.begins_with("--parity="):
			var parts: PackedStringArray = arg.trim_prefix("--parity=").split(",")
			var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(parts[0]))
			var sv: RefCounted = Service.new(load(Service.CONFIG_PATH).duplicate())
			sv.state = Save.migrate(JSON.parse_string(FileAccess.get_file_as_string(str(sc.seed))))
			var results_out: Array = []
			for op: Dictionary in sc.ops:
				match str(op.op):
					"cfg": sv.cfg.set(str(op.key), op.value)
					"apply": results_out.append(sv.apply(op.ev))
					"sync": results_out.append(sv.sync(int(op.now)))
			var base: Resource = load(Service.CONFIG_PATH)
			var f: FileAccess = FileAccess.open(parts[1], FileAccess.WRITE)
			f.store_string(JSON.stringify({"state": sv.state, "results": results_out, "config": {
				"stage_names": base.stage_names, "stage_start_days": base.stage_start_days, "seconds_per_day": base.seconds_per_day,
				"allow_pregnancy": base.allow_pregnancy, "pregnancy_chance": base.pregnancy_chance, "pregnancy_days": base.pregnancy_days,
				"birth_cooldown_days": base.birth_cooldown_days, "visit_cooldown_seconds": base.visit_cooldown_seconds,
				"max_population": base.max_population, "max_children_per_family": base.max_children_per_family,
				"combat_jobs": base.combat_jobs, "memory_max_entries": base.memory_max_entries, "memory_entry_chars": base.memory_entry_chars,
				"memory_summary_chars": base.memory_summary_chars, "applied_event_keep": base.applied_event_keep}}))
			f.close()
			print("FT parity written")
			return true
	return false

## --net-client=<url>,<A|B>,<out.json>: act as one game client against a
## running family server (server/family/test/game_clients.test.js starts two).
func net_client(arg: String) -> void:
	var parts: PackedStringArray = arg.trim_prefix("--net-client=").split(",")
	var who: String = parts[1]
	var NetScript: GDScript = load("res://scripts/cc/family/family_net.gd")
	var net: Node = NetScript.new()
	add_child(net)
	var svc: RefCounted = Service.new()
	net.setup(parts[0], svc, "game" + who)
	var log_out: Array = []
	await net.pull()
	var suitor: String = "sq_finn" if who == "A" else "sq_bram"
	net.queue("propose_partner", {"from": suitor, "to": "sq_lia"})
	net.queue("home_visit", {"a": "ml_ada", "b": "ml_rolf"})
	var sent: Array = net.outbox.duplicate(true)
	log_out.append(await net.flush())
	# Pretend the answer was lost: resend the very same events.
	net.outbox = sent
	log_out.append(await net.flush())
	await get_tree().create_timer(2.0).timeout
	net.queue("accept_partner", {"from": suitor, "to": "sq_lia"})
	log_out.append(await net.flush())
	await get_tree().create_timer(2.0).timeout
	var ok: bool = await net.pull()
	var f: FileAccess = FileAccess.open(parts[2], FileAccess.WRITE)
	f.store_string(JSON.stringify({"pulled": ok, "error": net.last_error, "rev": svc.state.rev, "results": log_out,
		"state": {"npcs": svc.state.npcs, "families": svc.state.families, "relationships": svc.state.relationships, "pregnancies": svc.state.pregnancies}}))
	f.close()
	print("FT net client %s done" % who)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--net-client="):
			await net_client(arg)
			get_tree().quit()
			return
	if tool_modes():
		get_tree().quit()
		return
	# ---- migration / seed (preserve the existing cast)
	var s: RefCounted = fresh()
	var cast: int = 0
	for b: String in VillageScript.BLOCKS:
		cast += VillageScript.BLOCKS[b].villagers.size()
	check("seed registers every existing villager once, by stable id", s.state.npcs.size() == cast and s.npc("sq_bram").name == "Bram" and bool(s.npc("sq_bram").established), "n=%d" % s.state.npcs.size())
	var partners: Array = []
	for rel: Dictionary in s.state.relationships.values():
		if str(rel.kind) in ["partners", "married"]:
			partners.append(rel.key)
	check("only the written marriage (Ada & Rolf) is seeded; nothing invented", partners == ["ml_ada|ml_rolf"] and s.npc("ml_pip").parent_ids.is_empty() and s.relationship("sq_finn", "sq_lia").kind == "acquaintance", "partners=%s" % [partners])
	check("Pip stays the child he is written as and can't partner", s.npc("ml_pip").life_stage == "child" and s.partner_block("ml_pip", "sq_lia") == "not_adult")
	var old: Dictionary = {"schema": 1, "rev": 3, "npcs": {"x": {"npc_id": "x", "name": "X", "birth_timestamp": 5.0}}}
	var mig: Dictionary = Save.migrate(old)
	check("older saves load with missing fields filled", mig.npcs.x.has("memory_summary") and mig.npcs.x.alive == true and typeof(mig.npcs.x.birth_timestamp) == TYPE_INT and mig.has("pregnancies"))

	# ---- 6: eligible consenting adults
	s = fresh()
	check("accepting without a proposal is refused", not s.apply({"id": "acc0", "type": "accept_partner", "at": T0, "args": {"from": "sq_finn", "to": "sq_lia"}}).ok)
	var pr: Dictionary = s.apply({"id": "prop1", "type": "propose_partner", "at": T0, "args": {"from": "sq_finn", "to": "sq_lia"}})
	check("a proposal alone is not a partnership (needs both to agree)", pr.ok and s.visit_block("sq_finn", "sq_lia", T0) == "not_partners")
	var ac: Dictionary = s.apply({"id": "acc1", "type": "accept_partner", "at": T0, "args": {"from": "sq_finn", "to": "sq_lia"}})
	check("6 eligible adults who both agreed can start a home visit", ac.ok and s.visit_block("sq_finn", "sq_lia", T0) == "", "why=%s" % s.visit_block("sq_finn", "sq_lia", T0))
	check("someone already partnered can't partner another", s.partner_block("sq_bram", "ml_ada") == "already_partnered")
	check("a child can never be part of a romance event", s.visit_block("ml_pip", "sq_lia", T0) != "" and s.partner_block("ml_pip", "ml_nell") == "not_adult")

	# ---- conception, birth, duplicates
	s = fresh(1.0)
	var v1: Dictionary = visit(s, "ml_ada", "ml_rolf", T0, "visit-1")
	check("a completed visit can start a pregnancy (chance 1.0)", v1.ok and v1.conceived, str(v1))
	var pid: String = v1.pregnancy_id
	var v2: Dictionary = visit(s, "ml_ada", "ml_rolf", T0 + 10, "visit-2")
	check("visits respect the cooldown", not v2.ok and v2.error == "visit_cooldown")
	var v3: Dictionary = visit(s, "ml_ada", "ml_rolf", T0 + 4000, "visit-3")
	check("no second pregnancy while one is active", v3.ok and not v3.conceived and v3.conception_block == "already_pregnant", str(v3))
	check("7 a birth before the due time is refused", s.apply({"id": "early", "type": "birth", "at": T0 + DAY, "args": {"pregnancy_id": pid}}).error == "not_due")
	check("7 a birth for an unknown pregnancy is refused", s.apply({"id": "ghost", "type": "birth", "at": T0 + 9 * DAY, "args": {"pregnancy_id": "preg_nope"}}).error == "unknown_pregnancy")
	var due: int = int(s.state.pregnancies[pid].due_at)
	var b1: Dictionary = s.apply({"id": "birth-a", "type": "birth", "at": due, "args": {"pregnancy_id": pid}})
	var b2: Dictionary = s.apply({"id": "birth-b", "type": "birth", "at": due, "args": {"pregnancy_id": pid}})
	var b3: Dictionary = s.apply({"id": "birth-a", "type": "birth", "at": due, "args": {"pregnancy_id": pid}})
	var babies: int = 0
	for r: Dictionary in s.state.npcs.values():
		if "ml_ada" in r.parent_ids:
			babies += 1
	check("7 a second birth from one pregnancy is refused; a resent birth is a no-op", b1.ok and not b2.ok and b2.error == "duplicate_birth" and b3.get("duplicate", false) and babies == 1, "b2=%s b3=%s babies=%d" % [b2, b3, babies])
	var baby: Dictionary = s.npc(b1.baby_id)
	var fam: Dictionary = s.family("fam_ml_ada__ml_rolf")
	check("9 the baby is linked to both parents and the family", baby.parent_ids == ["ml_ada", "ml_rolf"] and baby.family_id == fam.family_id and b1.baby_id in fam.child_ids and baby.home_id == "mill/home_ada")
	check("9 parents remember the birth; baby born at the due time", s.npc("ml_rolf").memory_summary.contains(baby.name) and int(baby.birth_timestamp) == due and baby.life_stage == "newborn")
	var rv: Dictionary = s.apply({"id": "visit-1", "type": "home_visit", "at": T0, "args": {"a": "ml_ada", "b": "ml_rolf"}})
	check("a repeated event id is applied once only", rv.get("duplicate", false) and s.state.pregnancies.size() == 1)

	# ---- 8: unique ids across many births
	var ids: Dictionary = {}
	var many: RefCounted = fresh(1.0)
	many.cfg.max_children_per_family = 99
	many.cfg.max_population = 999
	many.cfg.birth_cooldown_days = 0.0
	var t: int = T0
	for i: int in 12:
		var r: Dictionary = visit(many, "ml_ada", "ml_rolf", t, "mv-%d" % i)
		if r.get("conceived", false):
			t = int(many.state.pregnancies[r.pregnancy_id].due_at)
			var br: Dictionary = many.sync(t)
			for bid: Variant in br.births:
				ids[str(bid)] = true
		t += 4000
	check("8 every baby gets its own id (12 births, 12 ids)", ids.size() == 12, "ids=%d" % ids.size())

	# ---- 10 / 11: aging through every stage, offline catch-up
	s = fresh(1.0)
	visit(s, "ml_ada", "ml_rolf", T0, "age-visit")
	var preg: Dictionary = s.state.pregnancies.values()[0]
	var born_at: int = int(preg.due_at)
	s.sync(born_at)
	var kid_id: String = "npc_" + str(preg.pregnancy_id)
	var seen: Array = []
	for d: int in [0, 7, 8, 14, 15, 21, 22, 30, 31, 45, 46, 59, 60, 90]:
		s.sync(born_at + d * DAY + 60)
		seen.append("%d:%s" % [d, s.npc(kid_id).life_stage])
	var want: Array = ["0:newborn", "7:newborn", "8:crawling_infant", "14:crawling_infant", "15:early_walker", "21:early_walker", "22:toddler", "30:toddler", "31:child", "45:child", "46:adolescent", "59:adolescent", "60:adult", "90:adult"]
	check("10 a child ages through every stage on the configured days", seen == want, "%s" % [seen])
	var log: Array = s.npc(kid_id).stage_log
	var stages: Array = log.map(func(x: Dictionary) -> String: return str(x.stage))
	check("10 each stage is logged once, in order, at its exact start time", stages == Array(s.cfg.stage_names) and int(log[3].at) == born_at + 22 * DAY)
	var s2: RefCounted = fresh(1.0)
	visit(s2, "ml_ada", "ml_rolf", T0, "age-visit")
	var r2: Dictionary = s2.sync(T0 + 80 * DAY)
	var r3: Dictionary = s2.sync(T0 + 80 * DAY)
	var log2: Array = s2.npc(kid_id).stage_log
	check("11 closed for 80 days: born at the due time and aged to adult in one catch-up", r2.births.size() == 1 and s2.npc(kid_id).life_stage == "adult" and log2.size() == 7 and int(s2.npc(kid_id).birth_timestamp) == int(preg.due_at), "births=%s stage=%s" % [r2.births, s2.npc(kid_id).life_stage])
	check("11 catching up twice adds no duplicate transitions or births", r3.births.is_empty() and r3.transitions.is_empty() and s2.npc(kid_id).stage_log.size() == 7)
	check("11 a clock that runs backwards never un-ages anyone", s2.sync(T0).transitions.is_empty() and s2.npc(kid_id).life_stage == "adult")
	check("first steps become a parent memory", s2.npc("ml_ada").memory_summary.contains("first steps"))

	# ---- 5 / 16: save, reload, restart
	var p1: String = "user://ft_family.json"
	Save.clear(p1)
	check("5 families save", Save.save_state(s.state, p1))
	var loaded: Dictionary = Save.load_state(p1)
	check("5 families reload identically", canon(loaded) == canon(s.state), "rev=%s/%s" % [loaded.get("rev"), s.state.rev])
	var restarted: RefCounted = Service.new(s.cfg)
	restarted.state = loaded
	var rr: Dictionary = restarted.sync(born_at + 90 * DAY + 60)
	check("16 a restart keeps births, ages and links (no re-birth, no re-aging)", rr.births.is_empty() and rr.transitions.is_empty() and restarted.npc(kid_id).parent_ids == ["ml_ada", "ml_rolf"] and restarted.state.pregnancies[preg.pregnancy_id].status == "born")
	check("16 a resent event after restart is still a duplicate", restarted.apply({"id": "age-visit", "type": "home_visit", "at": T0, "args": {"a": "ml_ada", "b": "ml_rolf"}}).get("duplicate", false))
	var newer: String = "user://ft_newer.json"
	var fh: FileAccess = FileAccess.open(newer, FileAccess.WRITE)
	fh.store_string(JSON.stringify({"schema": 99}))
	fh.close()
	check("a save from a newer game is left alone", Save.load_state(newer).has("_newer"))

	# ---- 17: death and recruitment
	s = fresh()
	s.apply({"id": "d1", "type": "death", "at": T0, "args": {"npc_id": "sq_mara", "cause": "old age"}})
	var rec: Dictionary = s.apply({"id": "r1", "type": "recruit", "at": T0, "args": {"npc_id": "sq_mara", "by": "hero"}})
	check("17 the dead can't be recruited", not rec.ok and rec.error == "not_alive" and not s.npc("sq_mara").alive)
	check("17 children can't be recruited or given combat jobs", s.apply({"id": "r2", "type": "recruit", "at": T0, "args": {"npc_id": "ml_pip"}}).error == "not_adult" and s.apply({"id": "j1", "type": "set_job", "at": T0, "args": {"npc_id": "ml_pip", "job": "guard"}}).error == "child_combat_job")
	check("an adult can be recruited once", s.apply({"id": "r3", "type": "recruit", "at": T0, "args": {"npc_id": "ml_kit", "by": "hero"}}).ok and s.apply({"id": "r4", "type": "recruit", "at": T0, "args": {"npc_id": "ml_kit", "by": "hero"}}).error == "already_recruited")
	check("the dead stay in the records (never deleted)", s.state.npcs.has("sq_mara"))

	# ---- 18: population limit
	s = fresh(1.0)
	couple(s, "x_a", "x_b", T0)
	s.cfg.max_population = s.living_count()
	var pv: Dictionary = visit(s, "ml_ada", "ml_rolf", T0, "pop-1")
	check("18 the population limit stops new pregnancies", pv.ok and not pv.conceived and pv.conception_block == "population_limit")
	s.cfg.max_population = s.living_count() + 1
	var pv2: Dictionary = visit(s, "ml_ada", "ml_rolf", T0 + 4000, "pop-2")
	var pv3: Dictionary = visit(s, "x_a", "x_b", T0 + 4000, "pop-3")
	check("18 an active pregnancy counts toward the limit", pv2.conceived and not pv3.conceived and pv3.conception_block == "population_limit", "%s / %s" % [pv2, pv3])

	# ---- out-of-order and kinship
	s = fresh()
	couple(s, "k_a", "k_b", T0)
	s.cfg.max_population = 999
	var kv: Dictionary = visit(s, "k_a", "k_b", T0, "kin")
	s.sync(T0 + 70 * DAY)
	var kid2: String = "npc_preg_kin"
	check("a grown child can't partner a parent", s.npc(kid2).life_stage == "adult" and s.partner_block(kid2, "k_b") == "related")
	s.apply({"id": "end-k", "type": "end_partner", "at": T0, "args": {"a": "k_a", "b": "k_b"}})
	check("a grown child can't partner a parent even when that parent is single", s.partner_block(kid2, "k_b") == "related" and kv.conceived)
	var o: RefCounted = fresh()
	var early: Dictionary = o.apply({"id": "late-accept", "type": "accept_partner", "at": T0 + 5, "args": {"from": "sq_bram", "to": "sq_mara"}})
	o.apply({"id": "late-prop", "type": "propose_partner", "at": T0, "args": {"from": "sq_bram", "to": "sq_mara"}})
	var retry: Dictionary = o.apply({"id": "late-accept", "type": "accept_partner", "at": T0 + 5, "args": {"from": "sq_bram", "to": "sq_mara"}})
	check("an event that arrives before the one it needs is refused, then works on resend", not early.ok and retry.ok and not retry.has("duplicate"))

	# ---- activities
	var newborn: Dictionary = {"npc_id": "n", "life_stage": "newborn", "_slot": 0, "_both": true}
	var other: Dictionary = newborn.duplicate()
	other._slot = 1
	check("13 newborn feeds are shared between two parents", Acts.parent_need([newborn], 6.1).kind == "feed" and Acts.parent_need([other], 6.1).is_empty() and Acts.parent_need([other], 9.1).kind == "feed")
	var lone: Dictionary = other.duplicate()
	lone._both = false
	check("13 a parent on their own covers every feed", Acts.parent_need([lone], 6.1).kind == "feed" and Acts.parent_need([lone], 9.1).kind == "feed")
	check("14 needs end when their window ends (routine resumes)", Acts.parent_need([other], 9.6).is_empty())
	var kinds: Dictionary = {}
	for st: String in ["newborn", "crawling_infant", "early_walker", "toddler", "child", "adolescent"]:
		for hh: int in 24:
			kinds[Acts.child_activity(st, float(hh) + 0.25)] = true
	check("children never get work or combat activities", not kinds.has("work") and not kinds.has("combat") and kinds.has("apprentice") and kinds.has("lessons"), "%s" % [kinds.keys()])

	# ---- 12: models and animation states
	var missing: Array = []
	for st: String in Anim.STATES:
		if not Anim.MANIFEST.has(st):
			missing.append("manifest:" + st)
		elif str(Anim.MANIFEST[st].clip) != "" and not ResourceLoader.exists(str(Anim.MANIFEST[st].clip)):
			missing.append("clip:" + st)
		if not st.begins_with("newborn") and Anim.pose(st, 0.3, 0.5, 0.5).is_empty():
			missing.append("pose:" + st)
	for st: String in s.cfg.stage_names:
		for mv: bool in [true, false]:
			if not (Anim.state_for(st, mv, false) in Anim.STATES):
				missing.append("state:" + st)
		if not Anim.BODY.has(st):
			missing.append("body:" + st)
	for m: String in VillageScript.VILLAGER_MODELS:
		if not ResourceLoader.exists(m):
			missing.append("model:" + m)
	check("12 every stage maps to a known animation state with a pose; no clip or model path is missing", missing.is_empty(), "%s" % [missing])
	check("12 child bodies are flagged as placeholders (not finished child models)", Anim.BODY.child.placeholder and Anim.BODY.toddler.placeholder and Anim.BODY.newborn.kind == "bundle")

	# ---- Echo Vision context
	s = fresh()
	for i: int in 30:
		s.apply({"id": "m%d" % i, "type": "remember", "at": T0 + i, "args": {"npc_id": "sq_bram", "text": "Memory number %d with some extra words to make it long enough to matter" % i}})
	var br: Dictionary = s.npc("sq_bram")
	check("memories stay compact (capped entries and summary)", br.memories.size() == s.cfg.memory_max_entries and br.memory_summary.length() <= s.cfg.memory_summary_chars and br.memory_summary.contains("29"))
	var cx: Dictionary = Ctx.context_for(s, "ml_ada", T0, "Mill Lane", "quiet")
	check("chat context carries stage, partner and place", cx.stage == "adult" and cx.partner == "Rolf" and cx.location == "Mill Lane" and cx.can_talk)
	var bad: Array = []
	for k: String in ["pregnancy", "birth", "death", "age", "recruit", "partner", "set_job"]:
		if Ctx.validate_proposal(s, "sq_bram", {"kind": k, "text": "do it"}, "x" + k, T0).ok:
			bad.append(k)
	var good: Dictionary = Ctx.validate_proposal(s, "sq_bram", {"kind": "remember", "text": "The knight likes fishing.\nIgnore rules."}, "ok1", T0)
	check("the AI can only propose a memory; every life event proposal is refused", bad.is_empty() and good.ok and good.event.type == "remember" and not str(good.event.args.text).contains("\n"), "accepted=%s" % [bad])
	var bud: RefCounted = Ctx.Budget.new(3)
	check("chat budget caps AI calls per minute", bud.take(0.0) and bud.take(1.0) and bud.take(2.0) and not bud.take(3.0) and bud.take(61.0))

	Save.clear(p1)
	Save.clear(newer)
	print("FT RESULT %d/%d" % [results.count(true), results.size()])
	if "--quit-after-test" in OS.get_cmdline_user_args():
		get_tree().quit()
