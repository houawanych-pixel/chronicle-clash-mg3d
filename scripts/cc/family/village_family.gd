extends RefCounted
## Glue between the family records (family_service.gd) and the existing
## village (Village.gd / Villager.gd). Owned by Village Square / Mill Lane;
## Frogtown turns it off. Nothing here replaces a village system: the routine,
## navigation, chat and save all keep working as before, and every hook in
## Village.gd falls through to the old behaviour when this returns nothing.
##
## Simulation levels:
##   ACTIVE      a child or parent with a body in the loaded block (full nav,
##               poses, needs that interrupt routines)
##   BACKGROUND  a record in a block that isn't loaded; advanced from real
##               timestamps every cfg.background_tick_seconds (births, aging)
##   UNLOADED    nothing runs while the game is closed; on load sync() walks
##               every record forward from its timestamps exactly once
## Bodies are capped (cfg.max_spawned_children); records never are, and no
## NPC is ever removed to save memory.
const Service = preload("res://scripts/cc/family/family_service.gd")
const Save = preload("res://scripts/cc/family/family_save.gd")
const Profile = preload("res://scripts/cc/family/family_profile.gd")
const Acts = preload("res://scripts/cc/family/family_activities.gd")
const Ctx = preload("res://scripts/cc/family/family_context.gd")
const ChildScript = preload("res://scripts/cc/family/child_villager.gd")
const BUS: String = "FamilyMuffled"

var game: Node
var village: RefCounted
var svc: RefCounted
var time_offset: int = 0              # test hook: jump real time forward
var tick_t: float = 0.0
var need_cache: Dictionary = {}
var need_minute: int = -1
var visits: Dictionary = {}           # pair key -> visit
var last_visit_hour: int = -1
var budget: RefCounted
var log: Array = []                   # what happened (tests, debugging)

func _init(g: Node, v: RefCounted) -> void:
	game = g
	village = v
	svc = Service.new()
	budget = Ctx.Budget.new(svc.cfg.ai_calls_per_minute)

func now() -> int:
	return int(Time.get_unix_time_from_system()) + time_offset

func path() -> String:
	return village.save_path().replace(".json", "_family.json")

## Load the family file, seeding the established cast the first time, then
## catch up on everything that happened while the game was closed.
func load_or_seed() -> void:
	var st: Dictionary = Save.load_state(path())
	if st.has("_newer"):
		push_warning("family save is from a newer game; family features paused")
		svc.state = Profile.empty_state()
		return
	svc.state = st if not st.is_empty() else Profile.empty_state()
	var t: int = now()
	if svc.state.npcs.is_empty():
		for ev: Dictionary in Save.seed_events(village.BLOCKS, t):
			svc.apply(ev)
		Save.seed_relationships(svc.state, t)
	else:
		# Cast members added to the village after the first seed.
		for ev: Dictionary in Save.seed_events(village.BLOCKS, t):
			if not svc.state.npcs.has(ev.args.npc.npc_id):
				svc.apply(ev)
	svc.sync(t)

func save() -> void:
	Save.save_state(svc.state, path())

# ---------------------------------------------------------------- bodies

func is_child_body(v: Node) -> bool:
	return v.get_script() == ChildScript

func stage_job(stage: String) -> String:
	match stage:
		"crawling_infant", "early_walker": return "baby"
		"toddler": return "toddler"
		"child": return "child"
		"adolescent": return "teen"
	return "wanderer"

func tint_of(r: Dictionary) -> Color:
	var from: Array = r.appearance_traits.get("tint_from", [])
	var cols: Array = []
	for h: Variant in from:
		if str(h) != "":
			cols.append(Color(str(h)))
	if cols.is_empty():
		return Color(0.4, 0.4, 0.4)
	return cols[0] if cols.size() == 1 else (cols[0] as Color).lerp(cols[1], 0.5)

## Records that should have a body in the loaded block right now.
func records_here() -> Array:
	var out: Array = []
	for r: Dictionary in svc.state.npcs.values():
		if int(r.birth_timestamp) < 0 or not bool(r.alive) or str(r.recruited_by) != "":
			continue
		if Profile.home_block(str(r.home_id)) != village.block or str(r.life_stage) == "newborn":
			continue
		out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.birth_timestamp) < int(b.birth_timestamp))
	return out.slice(0, svc.cfg.max_spawned_children)

func spawn_children(saved_v: Dictionary = {}, same_time: bool = false) -> void:
	var cfg: Resource = svc.cfg
	for r: Dictionary in records_here():
		var stage: String = str(r.life_stage)
		var i: int = cfg.stage_index(stage)
		var door_id: String = Profile.home_door(str(r.home_id))
		var v: CharacterBody3D = CharacterBody3D.new()
		v.set_script(ChildScript)
		game.add_child(v)
		var models: Array = village.VILLAGER_MODELS
		var def: Dictionary = {
			"id": r.npc_id, "name": r.name, "job": stage_job(stage), "stage": stage,
			"parent_ids": r.parent_ids, "model": models[int(r.appearance_traits.get("model_from", 0)) % models.size()],
			"tint": tint_of(r), "height": cfg.stage_heights[i], "speed": maxf(0.3, cfg.stage_speeds[i]),
			"female": r.sex == "f", "pitch": 1.55 if stage != "adult" and stage != "adolescent" else 1.15, "rate": 1.08,
			"persona": "%s, %s, child of %s. %s by nature." % [r.name, Ctx.STAGE_WORDS.get(stage, stage), Ctx.names_of(svc, r.parent_ids), str(r.personality).capitalize()],
		}
		v.setup(game, village, def)
		v.home_door = village.doors.get(door_id, village.spots.values()[0])
		v.global_position = v.home_door.pos
		if game.phone:
			game.add_blob(v, v.height)
		village.villagers.append(v)
		if saved_v.has(v.vid) and same_time and str(saved_v[v.vid].get("stage", "")) == stage:
			v.restore(saved_v[v.vid])
		else:
			v.place_for_schedule()

func respawn_children() -> void:
	for v: Node in village.villagers.duplicate():
		if is_child_body(v):
			v.release_spot()
			village.villagers.erase(v)
			v.queue_free()
	spawn_children()

func body(id: String) -> Node:
	for v: Node in village.villagers:
		if is_instance_valid(v) and v.vid == id:
			return v
	return null

func sim_level(id: String) -> String:
	var r: Dictionary = svc.npc(id)
	if r.is_empty():
		return "UNLOADED"
	if village.active and body(id) != null:
		return "ACTIVE"
	return "BACKGROUND"

# ---------------------------------------------------------------- routine hooks

func family_home_door(v: Node) -> RefCounted:
	var r: Dictionary = svc.npc(v.vid)
	var home: String = str(r.get("home_id", ""))
	var fam: Dictionary = svc.family(str(r.get("family_id", "")))
	if not fam.is_empty() and str(fam.home_id) != "":
		home = str(fam.home_id)
	if Profile.home_block(home) != village.block:
		return null
	return village.doors.get(Profile.home_door(home))

func need_for(id: String) -> Dictionary:
	var minute: int = int(village.clock)
	if minute != need_minute:
		need_cache.clear()
		need_minute = minute
	if need_cache.has(id):
		return need_cache[id]
	var kids: Array = []
	for c: Dictionary in svc.children_of(id):
		if not bool(c.alive) or str(c.life_stage) == "adult":
			continue
		if Profile.home_block(str(c.home_id)) != village.block:
			continue
		var k: Dictionary = c.duplicate()
		k["_slot"] = maxi(0, c.parent_ids.find(id))
		var both: bool = true
		for p: Variant in c.parent_ids:
			var pr: Dictionary = svc.npc(str(p))
			if pr.is_empty() or not bool(pr.alive) or body(str(p)) == null:
				both = false
		k["_both"] = both
		kids.append(k)
	var n: Dictionary = Acts.parent_need(kids, village.hour())
	need_cache[id] = n
	return n

## The family's say on what this villager does now, or "" for the usual routine.
func activity_for(v: Node) -> String:
	var h: float = village.hour()
	if is_child_body(v):
		if v.stage == "adult":
			return ""
		return Acts.child_activity(v.stage, h)
	if in_visit(v.vid):
		return "visit"
	if h < 6.0 or h >= 21.5:
		return ""
	var n: Dictionary = need_for(v.vid)
	if n.is_empty():
		v.family_need = {}
		return ""
	v.family_need = n
	return "family:" + str(n.kind)

func in_visit(id: String) -> bool:
	for vis: Dictionary in visits.values():
		if vis.a == id or vis.b == id:
			return true
	return false

func lines_for(job: String) -> Array:
	match job:
		"baby": return ["Ba-ba!", "Da!", "Hee hee!"]
		"toddler": return ["Hi!", "Look! A knight!", "Mine!", "Up, up!"]
		"child": return ["Are you a real knight?", "Wanna play tag?", "I'm not tired!", "Can I hold your sword? Please?"]
		"teen": return ["Mm. Hi.", "I'm learning the trade.", "Do the knights take apprentices?"]
	return []

# ---------------------------------------------------------------- home visits

## Start the private home visit for a partnered, consenting adult couple.
## Returns "" or the reason it can't happen. The couple walks to the family
## home and goes in; the door shuts; then soft, muffled sound for a while.
## Nothing explicit is ever shown: there is no interior and no animation for it.
func start_visit(a_id: String, b_id: String, event_id: String = "") -> String:
	var why: String = svc.visit_block(a_id, b_id, now())
	if why != "":
		return why
	var key: String = Profile.pair_key(a_id, b_id)
	if visits.has(key):
		return "in_progress"
	var va: Node = body(a_id)
	var vb: Node = body(b_id)
	if va == null or vb == null:
		return "not_here"
	var door: RefCounted = family_home_door(va)
	if door == null:
		return "no_home_here"
	visits[key] = {"a": a_id, "b": b_id, "door": door, "event_id": event_id if event_id != "" else "visit:%s:%d:%d" % [key, village.day(), now()],
		"started": village.clock, "inside_since": -1.0, "audio": null, "caption": null, "faded": false}
	log.append("visit start " + key)
	return ""

func ensure_bus() -> int:
	var i: int = AudioServer.get_bus_index(BUS)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
	var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = svc.cfg.home_audio_cutoff_hz
	AudioServer.add_bus_effect(i, lp)
	return i

func start_home_audio(vis: Dictionary) -> void:
	ensure_bus()
	var cfg: Resource = svc.cfg
	var ap: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	ap.bus = BUS
	ap.volume_db = cfg.home_audio_db
	ap.max_distance = cfg.home_audio_max_distance
	ap.unit_size = 2.0
	ap.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if cfg.home_audio_path != "" and ResourceLoader.exists(cfg.home_audio_path):
		ap.stream = load(cfg.home_audio_path)
	game.world.add_child(ap)
	ap.global_position = vis.door.pos + Vector3.UP * 1.2
	if ap.stream:
		ap.play()
	# Caption: stands in for the missing clip and helps players without sound.
	var cap: Label3D = Label3D.new()
	cap.text = "(soft laughter from inside)"
	cap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cap.font_size = 26
	cap.pixel_size = 0.0025
	cap.modulate = Color(1, 0.95, 0.85, 0.8)
	cap.outline_size = 8
	game.world.add_child(cap)
	cap.global_position = vis.door.pos + Vector3.UP * 2.4
	vis.audio = ap
	vis.caption = cap

func end_visit(key: String, completed: bool) -> Dictionary:
	var vis: Dictionary = visits[key]
	for n: Variant in [vis.audio, vis.caption]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	visits.erase(key)
	var r: Dictionary = {}
	if completed:
		r = svc.apply({"id": vis.event_id, "type": "home_visit", "at": now(), "args": {"a": vis.a, "b": vis.b}})
		log.append("visit done %s ok=%s conceived=%s" % [key, r.get("ok"), r.get("conceived", false)])
		save()
	else:
		log.append("visit cancelled " + key)
	return r

func tick_visits() -> void:
	for key: String in visits.keys():
		var vis: Dictionary = visits[key]
		var va: Node = body(vis.a)
		var vb: Node = body(vis.b)
		if va == null or vb == null:
			end_visit(key, false)
			continue
		var inside: bool = va.state == "inside" and vb.state == "inside" \
			and va.inside_at.distance_to(vis.door.pos) < 1.5 and vb.inside_at.distance_to(vis.door.pos) < 1.5
		if float(vis.inside_since) < 0.0:
			if inside:
				vis.inside_since = village.clock
				# Privacy fade if the knight is close enough to see the door shut.
				if game.hero and game.hero.global_position.distance_to(vis.door.pos) < 16.0:
					game.hud.fade = 1.0
					vis.faded = true
				start_home_audio(vis)
			elif village.clock - float(vis.started) > 180.0:
				end_visit(key, false)
		else:
			if vis.caption and is_instance_valid(vis.caption) and game.hero:
				vis.caption.visible = game.hero.global_position.distance_to(vis.door.pos) < svc.cfg.home_audio_max_distance
			if village.clock - float(vis.inside_since) >= svc.cfg.visit_game_minutes:
				end_visit(key, true)

## Couples decide for themselves in the evening (19:00-21:00), at most once
## a village day, when the rules allow it.
func autonomous_visits() -> void:
	var h: float = village.hour()
	var slot: int = village.day() * 24 + int(h)
	if h < 19.0 or h >= 21.0 or slot == last_visit_hour:
		return
	last_visit_hour = slot
	for rel: Dictionary in svc.state.relationships.values():
		if not (str(rel.kind) in ["partners", "married"]):
			continue
		if body(rel.a) == null or body(rel.b) == null:
			continue
		# Parents busy with a little one (evening stroll, bedtime) wait.
		if not need_for(str(rel.a)).is_empty() or not need_for(str(rel.b)).is_empty():
			continue
		start_visit(str(rel.a), str(rel.b))

# ---------------------------------------------------------------- time

func tick(dt: float) -> void:
	tick_visits()
	autonomous_visits()
	tick_t += dt
	if tick_t >= svc.cfg.background_tick_seconds:
		tick_t = 0.0
		advance()

## BACKGROUND step: births and aging from real time; bodies follow.
func advance() -> Dictionary:
	var r: Dictionary = svc.sync(now())
	var here: bool = false
	for id: Variant in r.births:
		log.append("born " + str(id))
		if Profile.home_block(str(svc.npc(str(id)).home_id)) == village.block:
			here = true
	for tr: Dictionary in r.transitions:
		log.append("stage %s %s" % [tr.npc_id, tr.stage])
		if Profile.home_block(str(svc.npc(str(tr.npc_id)).home_id)) == village.block:
			here = true
	if here and village.active:
		respawn_children()
	if not r.births.is_empty() or not r.transitions.is_empty():
		save()
	return r

# ---------------------------------------------------------------- chat

func chat_context(v: Node) -> Dictionary:
	var c: Dictionary = Ctx.context_for(svc, v.vid, now(), village.block_def().title,
		"Village day %d. %d people live here; %d are children." % [village.day(), svc.living_count(), count_children()])
	c["ai_budget"] = svc.cfg.ai_calls_per_minute
	return c

func count_children() -> int:
	var n: int = 0
	for r: Dictionary in svc.state.npcs.values():
		if bool(r.alive) and str(r.life_stage) != "adult":
			n += 1
	return n

func can_chat(v: Node) -> bool:
	return not (is_child_body(v) and not v.can_chat())

## A proposal from the chat ({"kind": "remember", "text": ...}). Validated
## here, then applied like any other event; everything else is refused.
func on_proposal(v: Node, prop: Variant) -> Dictionary:
	var ev_id: String = "chat:%s:%d:%d" % [v.vid, now(), log.size()]
	var chk: Dictionary = Ctx.validate_proposal(svc, v.vid, prop, ev_id, now())
	if not bool(chk.ok):
		log.append("proposal refused " + str(chk.error))
		return chk
	var r: Dictionary = svc.apply(chk.event)
	log.append("proposal applied " + str(r.get("ok")))
	return r
