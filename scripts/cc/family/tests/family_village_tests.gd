extends RefCounted
## Family module inside the real village (Citadel scene). Run:
##   godot --headless res://scenes/citadel.tscn -- --autotest --family-only --quit-after-test
## Uses AutoTest.gd's check()/wait(); prints "CITADEL PASS/FAIL FV ..." lines.
const SaveScript = preload("res://scripts/citadel/VillageSave.gd")
const Anim = preload("res://scripts/cc/family/child_anim.gd")
const DAY: int = 86400

var t: Node
var game: Node

func vill(id: String) -> Node:
	for v: Node in game.village.villagers:
		if is_instance_valid(v) and v.vid == id:
			return v
	return null

func set_hour(h: float) -> void:
	var vg: RefCounted = game.village
	vg.clock = floor(vg.clock / 1440.0) * 1440.0 + h * 60.0
	if h * 60.0 < fmod(vg.clock, 1440.0) - 1.0:
		vg.clock += 1440.0

func next_day_at(h: float) -> void:
	var vg: RefCounted = game.village
	vg.clock = (floor(vg.clock / 1440.0) + 1.0) * 1440.0 + h * 60.0

func wait_until(cond: Callable, seconds: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		if cond.call():
			return true
		await t.wait(0.25)
	return cond.call()

func run(autotest: Node) -> void:
	t = autotest
	game = t.game
	SaveScript.clear()
	game.restart_with("blonde_lance", "village")
	await t.wait(0.3)
	game.start_game()
	await t.wait(0.6)
	var vg: RefCounted = game.village
	var fam: RefCounted = vg.family
	var cfg: Resource = fam.svc.cfg
	var keep_chance: float = cfg.pregnancy_chance
	cfg.pregnancy_chance = 1.0
	t.check("FV 1 the village loads as before (6 villagers, nav mesh) with the family module seeded", vg.block == "square" and vg.villagers.size() == 6 and vg.region.navigation_mesh.get_polygon_count() > 20 and fam != null and fam.svc.state.npcs.size() == 12, "n=%d recs=%d" % [vg.villagers.size(), fam.svc.state.npcs.size()])
	t.check("FV 1 Frogtown keeps its own village with the family module off", game.frogtown.family == null)
	# ---- Mill Lane: the married couple.
	vg.switch_block("mill", Vector3(-16.0, 0.2, 0.0))
	await t.wait(0.8)
	var ada: Node = vill("ml_ada")
	var rolf: Node = vill("ml_rolf")
	t.check("FV the east block loads Mill Lane with Ada and Rolf", vg.block == "mill" and ada != null and rolf != null and vg.villagers.size() == 6)
	# ---- 6: home visit (privacy)
	set_hour(19.05)
	vg.speed = 10.0
	await t.wait(0.3)
	var key: String = "ml_ada|ml_rolf"
	var why: String = fam.start_visit("ml_ada", "ml_rolf")
	t.check("FV 6 an eligible couple starts a home visit", why == "" or (why == "in_progress" and fam.visits.has(key)), "why=%s" % why)
	t.check("FV 6 a child can't be part of one", fam.start_visit("ml_pip", "ml_nell") != "")
	var vis: Dictionary = fam.visits.get(key, {})
	var both_in: bool = await wait_until(func() -> bool: return ada.state == "inside" and rolf.state == "inside" and float(vis.get("inside_since", -1.0)) >= 0.0, 40.0)
	var door: Vector3 = vg.doors["home_ada"].pos
	t.check("FV 6 the couple walk to the family home and go in; the door shuts", both_in and ada.inside_at.distance_to(door) < 1.5 and rolf.inside_at.distance_to(door) < 1.5, "ada=%s rolf=%s" % [ada.state, rolf.state])
	var ap: Node = vis.get("audio")
	t.check("FV 6 privacy: fade near the door, muffled sound on its own low-pass bus that fades with distance", bool(vis.get("faded", false)) and ap is AudioStreamPlayer3D and ap.bus == fam.BUS and AudioServer.get_bus_effect(AudioServer.get_bus_index(fam.BUS), 0) is AudioEffectLowPassFilter and ap.max_distance > 0.0 and ap.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED)
	t.check("FV 6 nothing is shown: both stay hidden indoors", not ada.visible and not rolf.visible)
	var done: bool = await wait_until(func() -> bool: return not fam.visits.has(key), 40.0)
	var out: bool = await wait_until(func() -> bool: return ada.state != "inside" and rolf.state != "inside", 20.0)
	t.check("FV 6 afterwards the visit is recorded and both go back to their evening", done and out and fam.svc.state.pregnancies.size() == 1, "log=%s" % [fam.log])
	await t.shot("fam1_after_visit")
	cfg.pregnancy_chance = 0.0     # one baby is enough for the rest of this run
	# ---- birth (while the game runs; real time jumped forward)
	fam.time_offset += int(cfg.pregnancy_days * DAY) + 3600
	var adv: Dictionary = fam.advance()
	var baby_id: String = str(adv.births[0]) if adv.births.size() == 1 else ""
	var baby: Dictionary = fam.svc.npc(baby_id)
	t.check("FV a baby is born to Ada and Rolf, linked to both, living in the family home", baby_id != "" and baby.parent_ids == ["ml_ada", "ml_rolf"] and baby.home_id == "mill/home_ada" and baby.life_stage == "newborn", "adv=%s" % [adv])
	t.check("FV a newborn has no walking body (a parent carries the bundle)", vill(baby_id) == null and vg.villagers.size() == 6)
	# ---- 13 / 14: a feed pulls Rolf off the field, then he goes back to work
	next_day_at(8.6)
	vg.speed = 2.0
	await wait_until(func() -> bool: return rolf.activity == "work", 20.0)
	var seen: Array = []
	var went_home: bool = false
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and vg.hour() < 10.6:
		await t.wait(0.25)
		if seen.is_empty() or seen[seen.size() - 1] != rolf.activity:
			seen.append(rolf.activity)
		went_home = went_home or (rolf.state == "inside" and rolf.inside_at.distance_to(door) < 1.5)
		if seen.size() >= 3 and seen[seen.size() - 1] == "work" and rolf.state == "work":
			break
	t.check("FV 13 at feeding time the parent leaves work and goes home to the baby", "family:feed" in seen and went_home, "seen=%s" % [seen])
	t.check("FV 14 when the feed is done the routine resumes (back to work)", seen.size() >= 3 and seen[seen.size() - 1] == "work" and rolf.state in ["work", "walk"], "seen=%s state=%s" % [seen, rolf.state])
	var wes: Node = vill("ml_wes")
	var kit: Node = vill("ml_kit")
	t.check("FV 2 the other villagers keep their jobs", wes.job == "miller" and kit.job == "woodcutter" and vill("ml_nell").job == "fisher" and (kit.activity == "work" or wes.activity == "work"))
	# ---- parent carry: evening stroll with the newborn
	vg.speed = 6.0
	set_hour(19.1)
	var carried: bool = await wait_until(func() -> bool: return ada.carrying_baby and ada.baby_bundle != null and ada.baby_bundle.visible and ada.state != "inside", 25.0)
	t.check("FV parent_carry: Ada takes the newborn out in her arms", carried, "act=%s state=%s" % [ada.activity, ada.state])
	await t.shot("fam2_carry")
	# ---- 3 / 10: the child grows into bodies that walk the nav mesh
	var stages_seen: Array = []
	var bad: Array = []
	for step: Array in [[8, "crawling_infant", 9.5], [7, "early_walker", 9.5], [7, "toddler", 15.0], [9, "child", 10.0], [15, "adolescent", 9.0]]:
		fam.time_offset += int(step[0]) * DAY
		fam.advance()
		next_day_at(float(step[2]))
		await t.wait(0.4)
		var kid: Node = vill(baby_id)
		if kid == null:
			bad.append("no body at " + str(step[1]))
			continue
		stages_seen.append(kid.stage)
		var p0: Vector3 = kid.global_position
		var moved: bool = await wait_until(func() -> bool: return kid.global_position.distance_to(p0) > 0.8, 25.0)
		if kid.stage != step[1] or absf(kid.height - cfg.stage_heights[cfg.stage_index(step[1])]) > 0.01:
			bad.append("stage/height " + str(step[1]))
		if not moved:
			bad.append("did not move as " + str(step[1]))
		if not (kid.anim_state in Anim.STATES):
			bad.append("anim " + kid.anim_state)
		if absf(kid.global_position.x) > 20.5 or absf(kid.global_position.z) > 20.5:
			bad.append("left the block")
		if step[1] == "crawling_infant":
			t.check("FV 12 the crawling infant uses the crawl state", kid.anim_state == "crawl", kid.anim_state)
			t.check("FV infants don't open a chat", not fam.can_chat(kid))
			await t.shot("fam3_crawl")
		if step[1] == "toddler":
			t.check("FV toddlers can talk (a few words)", fam.can_chat(kid))
		if step[1] == "child":
			t.check("FV a school-age child goes to lessons, never to a work spot", kid.activity == "lessons" and kid.spot == null, kid.activity)
			await t.shot("fam4_child")
		if step[1] == "adolescent":
			t.check("FV a teenager apprentices near a parent (no combat job)", kid.activity == "apprentice" and not (kid.job in cfg.combat_jobs), kid.activity)
	t.check("FV 3 the child walks the village nav mesh at every stage and stays in the block", bad.is_empty() and stages_seen == ["crawling_infant", "early_walker", "toddler", "child", "adolescent"], "%s %s" % [stages_seen, bad])
	# ---- 4: chat remains, with family context
	var ch: RefCounted = vg.chat
	vg.speed = 1.0
	vg.speed = 6.0
	set_hour(10.0)
	await wait_until(func() -> bool: return ada.state != "inside" and ada.visible, 20.0)
	vg.speed = 1.0
	t.place(ada.global_position + Vector3(1.2, 0.2, 0.0), PI / 2.0)
	ch.start(ada)
	await t.wait(0.2)
	ch.send("How is your family?")
	await t.wait(0.4)
	var ctx: Dictionary = ch.context(ada)
	t.check("FV 4 chat still works and now knows the family", ch.is_open() and ch.replies.size() == 1 and str(ctx.get("family", {}).get("children", "")).contains(baby.name) and ctx.family.partner == "Rolf", "ctx=%s" % [ctx.get("family")])
	ch.handle({"t": "propose", "proposal": {"kind": "remember", "text": "The knight asked after the family."}})
	ch.handle({"t": "propose", "proposal": {"kind": "pregnancy", "text": "make a baby"}})
	t.check("FV 4 chat may add a memory but can't decide a life event", fam.svc.npc("ml_ada").memory_summary.contains("asked after the family") and fam.log.any(func(s: String) -> bool: return s.begins_with("proposal refused")))
	ch.stop()
	# ---- 5 / 16: save, leave, come back
	vg.save_now()
	var recs: int = fam.svc.state.npcs.size()
	var kid_stage: String = fam.svc.npc(baby_id).life_stage
	var offset: int = fam.time_offset
	game.restart_with("blonde_lance", "classic")
	await t.wait(0.4)
	t.check("FV leaving the village frees every body, children included", vg.villagers.is_empty())
	game.restart_with("blonde_lance", "village")
	fam.time_offset = offset
	await t.wait(0.4)
	game.start_game()
	await t.wait(0.4)
	if vg.block != "mill":
		vg.switch_block("mill", Vector3(-16.0, 0.2, 0.0))
		await t.wait(0.6)
	t.check("FV 5/16 after leaving and reloading the family records and the child come back", fam.svc.state.npcs.size() == recs and fam.svc.npc(baby_id).life_stage == kid_stage and vill(baby_id) != null and vill(baby_id).stage == kid_stage, "recs=%d/%d" % [fam.svc.state.npcs.size(), recs])
	t.check("FV sim levels: bodies here are ACTIVE, Village Square records are BACKGROUND", fam.sim_level(baby_id) == "ACTIVE" and fam.sim_level("sq_bram") == "BACKGROUND")
	cfg.pregnancy_chance = keep_chance
	vg.speed = 1.0
	SaveScript.clear()
