extends "res://scripts/citadel/Ruin.gd"
## Sky Citadel v3: the old sky ruin's real shape rebuilt in clean stone (art/castle2,
## castle3.py), with three ways up:
##   A  the outer ledges (the proven ring route: broken bridge, ledges, ladders),
##   B  the inner tower (front door, spiral stair inside, broken-arch bridge),
##   C  the sky path (hover platforms and crystal launch pads).
## All reconnect at the Ring 2 hub and the Core Floor hub, then the sky stair to
## the crown and the drop through the eye into the Core. assets/ruin3/route3.json
## is written by route3.py (positions, gaps and the test bot's moves).

const ROUTE3: String = "res://assets/ruin3/route3.json"
const FRAGMENTS: String = "res://assets/ruin3/fragments.glb"
const PAD: String = "res://assets/ruin3/crystal_pad.glb"

var plats: Array = []          # {body, base, phase}
var pads: Array = []           # {plat, node, to, unlock, active}
var best_y: float = 0.0
var t: float = 0.0

func load_route() -> void:
	var f: FileAccess = FileAccess.open(ROUTE3, FileAccess.READ)
	route = JSON.parse_string(f.get_as_text())
	core_y = route.core_y
	crown_y = route.crown_y
	dock = v3(route.dock)
	var e: Array = route.eye
	eye = Rect2(e[0], e[2], e[1] - e[0], e[3] - e[2])
	sections.clear()
	for i in route.spawns.size():
		sections.append({"goal": route.goals[i], "spawn": v3(route.spawns[i])})
	last = sections.size() - 1

func build() -> void:
	configure()
	root = Node3D.new()
	root.name = "SkyRuin"
	game.world.add_child(root)
	game.ladders.clear()
	look()
	add_route()
	add_castle3()
	add_platforms()
	add_sky()

func look() -> void:
	game.citadel_look()
	game.env_res.fog_density = 0.0009
	game.env_res.tonemap_exposure = 0.75
	game.env_res.ambient_light_energy = 0.5
	game.sun.light_energy = 0.8
	game.sun.rotation_degrees = Vector3(-40, 38, 0)
	if game.sun.shadow_enabled:
		game.sun.directional_shadow_max_distance = 60.0

const MODEL3: String = "res://assets/ruin3/skycitadel.glb"
const COLLIDER3: String = "res://assets/ruin3/skycitadel_col.glb"

func add_castle3() -> void:
	var castle: Node3D = (load(MODEL3) as PackedScene).instantiate()
	root.add_child(castle)
	for mi: MeshInstance3D in castle.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.phone else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var col_scene: Node3D = (load(COLLIDER3) as PackedScene).instantiate()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RuinCollision"
	for mi: MeshInstance3D in col_scene.find_children("*", "MeshInstance3D", true, false):
		var cps: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cps.set_faces(mi.mesh.get_faces())
		cps.backface_collision = true
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = cps
		body.add_child(shape)
	col_scene.free()
	root.add_child(body)

func add_platforms() -> void:
	plats.clear()
	pads.clear()
	var frags: Node3D = (load(FRAGMENTS) as PackedScene).instantiate()
	var padscene: PackedScene = load(PAD)
	var i: int = 0
	for pd: Dictionary in route.platforms:
		var base: Vector3 = v3(pd.pos)
		var body: AnimatableBody3D = AnimatableBody3D.new()
		body.sync_to_physics = true
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = Vector3(4.0, 0.6, 3.8)
		cs.shape = sh
		cs.position = Vector3(0, -0.3, 0)
		body.add_child(cs)
		var src: Node = frags.find_child("frag%d" % int(pd.get("variant", i % 4)), true, false)
		if src:
			var mesh: Node3D = src.duplicate()
			mesh.transform = Transform3D.IDENTITY
			body.add_child(mesh)
		root.add_child(body)
		body.global_position = base
		body.rotation.y = float(pd.get("yaw", 0.0))
		var rec: Dictionary = {"body": body, "base": base, "phase": float(i) * 0.9}
		plats.append(rec)
		if pd.get("pad") != null:
			var pad: Node3D = padscene.instantiate()
			body.add_child(pad)
			pad.position = Vector3(0, 0.02, 0)
			pads.append({"plat": rec, "node": pad, "to": v3(pd.pad.to), "unlock": pd.pad.unlock, "active": false})
		i += 1
	frags.free()

func pad_unlocked(p: Dictionary) -> bool:
	match p.unlock:
		"ring1":
			return game.section >= 1 and best_y > 55.5
		"ring2":
			return game.checkpoint >= 1
		"core":
			return game.checkpoint >= 2
	return true

func platforms_tick(dt: float) -> void:
	t += dt
	for p: Dictionary in plats:
		var b: AnimatableBody3D = p.body
		if is_instance_valid(b):
			b.global_position = (p.base as Vector3) + Vector3(0, 0.15 * sin(t * 1.6 + p.phase), 0)
	if game.hero == null:
		return
	var h: CharacterBody3D = game.hero
	best_y = maxf(best_y, h.global_position.y if h.is_on_floor() else best_y)
	for p: Dictionary in pads:
		var on: bool = pad_unlocked(p)
		if on != p.active:
			p.active = on
			(p.node as Node3D).visible = true
			for mi: MeshInstance3D in (p.node as Node3D).find_children("*", "MeshInstance3D", true, false):
				mi.transparency = 0.0 if on else 0.65
			if on:
				game.burst((p.plat.body as Node3D).global_position + Vector3(0, 0.5, 0), Color("6fe0ff"), 20, 4.0)
		if not p.active or h.state != "idle":
			continue
		var c: Vector3 = (p.plat.body as Node3D).global_position
		var hp: Vector3 = h.global_position
		if Vector2(hp.x - c.x, hp.z - c.z).length() < 1.3 and absf(hp.y - c.y) < 1.0 and h.is_on_floor():
			game.start_launch(h, p.to)
			game.say_once("pad_tip", "tip", "Crystal pads launch you to the next level once they glow.")

func start() -> void:
	game.say_once("ruin_start", "hero", "Elyza's held in the Core, under the crown. The Dark Knight guards her.")
	game.say_once("ruin_tip", "tip", "Three ways up: the outer ledges, the tower inside, or the floating platforms.")

func progress() -> void:
	platforms_tick(game.get_process_delta_time())
	rescue_tick(game.get_process_delta_time())
	spawn_nearby()
	if game.section < last and game.section_clear(game.section):
		game.open_barrier(game.section)
		game.section += 1
		match game.section:
			1:
				game.say("tip", "The way's open. Ledges to the right, the tower door ahead, or the floating stones.")
			2:
				game.say("hero", "Ring 2 is clear. On to the Core Floor.")
			3:
				game.say("tip", "Up the sky stair to the crown!")
			4:
				game.say("hero", "The eye is open. Elyza's down there. Jump!")
	var p: Vector3 = game.hero.global_position
	var reached: int = game.checkpoint
	for i in range(sections.size() - 1, 0, -1):
		var s: Vector3 = sections[i].spawn
		if p.y > s.y - 1.2 and p.y < s.y + 3.0 and Vector2(p.x - s.x, p.z - s.z).length() < 6.0:
			reached = maxi(reached, i)
			break
	if in_core():
		reached = last
	if reached > game.checkpoint and reached <= game.section:
		game.checkpoint = reached
	if not game.boss_seen and in_core() and game.hero.is_on_floor():
		game.boss_seen = true
		game.boss.active = true
		game.sound("alarm", -8)
		game.say("boss", "You fell all this way to die in my core?")
		game.say("ally", "Lance! Watch out, he's fast!")

## Ledges and ramps get glowing crystal inlays along both edges (the path reads at a glance).
func walk(a: Vector3, b: Vector3, width: float = 3.0) -> void:
	super.walk(a, b, width)
	var flat: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z)
	var length: float = flat.length()
	if length < 0.5:
		return
	var basis: Basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	var pitch: float = atan2(b.y - a.y, length)
	var n: Node3D = Node3D.new()
	root.add_child(n)
	n.transform = Transform3D(basis * Basis(Vector3.RIGHT, pitch), (a + b) * 0.5 + Vector3(0, 0.04, 0))
	var ramp: float = sqrt(length * length + (b.y - a.y) * (b.y - a.y))
	for s: float in [-1.0, 1.0]:
		game.box(Vector3(s * (width * 0.5 - 0.32), 0.0, 0), Vector3(0.1, 0.04, ramp), "crystal", false, n)

# ---------------------------------------------------------------- rescue
## Elyza is held in a crystal cage in the Core. Beat the Dark Knight to free her,
## ride the escape pad up through the eye, then bring her to the skyship landing
## on the crown (the safe area) to clear the stage.
const CAPTIVE: Vector3 = Vector3(-7.5, 105.0, -4.5)
const ESCAPE_PAD: Vector3 = Vector3(6.0, 105.0, 1.0)
const ESCAPE_TO: Vector3 = Vector3(0.0, 139.3, 10.5)
const SAFE: Vector3 = Vector3(-5.3, 139.3, 18.5)
var cage: Node3D
var escape: Node3D
var beacon: Node3D
var rescue: String = ""     # "", "freed", "escort", "safe"
var ambush: Array = []
var safe_t: float = 0.0

func spawn_cast() -> void:
	super.spawn_cast()
	game.ally_captive = true
	game.ally.global_position = CAPTIVE
	game.ally.yaw = atan2(CAPTIVE.x, CAPTIVE.z)
	rescue = ""
	ambush.clear()
	safe_t = 0.0
	build_cage()

func captive_pos() -> Vector3:
	return CAPTIVE

func build_cage() -> void:
	cage = Node3D.new()
	cage.name = "CrystalCage"
	root.add_child(cage)
	cage.global_position = CAPTIVE
	for i in 8:
		var a: float = i * TAU / 8.0
		var bar: MeshInstance3D = game.box(Vector3(cos(a) * 1.15, 1.35, sin(a) * 1.15), Vector3(0.16, 2.7, 0.16), "crystal", false, cage)
		bar.rotation.y = -a
	game.box(Vector3(0, 2.75, 0), Vector3(2.5, 0.14, 2.5), "gold", false, cage)
	game.box(Vector3(0, 0.06, 0), Vector3(2.6, 0.12, 2.6), "gold", false, cage)
	if not game.phone:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color("6fe0ff")
		l.light_energy = 1.4
		l.omni_range = 5.0
		l.position = Vector3(0, 1.6, 0)
		cage.add_child(l)

func boss_down() -> void:
	## The Dark Knight falls: the cage shatters and Elyza is free.
	game.hud.popup("DARK KNIGHT DEFEATED", Color("ffd27a"))
	game.get_tree().create_timer(1.4).timeout.connect(free_ally)

func free_ally() -> void:
	if rescue != "":
		return
	rescue = "freed"
	game.ally_captive = false
	if is_instance_valid(cage):
		game.burst(CAPTIVE + Vector3(0, 1.4, 0), Color("6fe0ff"), 60, 7.0)
		game.ring(CAPTIVE + Vector3(0, 0.1, 0), 3.0, Color("6fe0ff"), 0.7)
		cage.queue_free()
	game.sound("explosion", -12)
	game.hud.popup("ELYZA RESCUED", Color("7dffcf"))
	game.say("ally", "Lance! You came for me!")
	game.say("hero", "Stay close. The crystal pad under the eye will take us up.")
	game.say("tip", "Escort Elyza to the skyship landing on the crown (the gold light).")
	# escape pad under the eye
	escape = (load(PAD) as PackedScene).instantiate()
	root.add_child(escape)
	escape.global_position = ESCAPE_PAD + Vector3(0, 0.02, 0)
	escape.scale = Vector3.ONE * 1.3
	game.burst(ESCAPE_PAD + Vector3(0, 0.5, 0), Color("6fe0ff"), 30, 5.0)
	add_beacon()

func add_beacon() -> void:
	## A tall gold light pillar marks the safe area (seen from the core through the eye).
	beacon = Node3D.new()
	root.add_child(beacon)
	beacon.global_position = SAFE
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.6
	cm.height = 40.0
	cm.radial_segments = 12
	mi.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.8, 0.35, 0.35)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 20.0, 0)
	beacon.add_child(mi)
	game.box(Vector3(0, 0.05, 0), Vector3(3.4, 0.08, 3.4), "gold", false, beacon)

func rescue_tick(dt: float) -> void:
	if rescue == "" or rescue == "safe" or game.hero == null:
		return
	var h: CharacterBody3D = game.hero
	var hp: Vector3 = h.global_position
	if is_instance_valid(escape):
		escape.rotation.y += dt * 1.5
		# the pad works every time (in case you drop back through the eye)
		if h.state == "idle" and h.is_on_floor() and Vector2(hp.x - ESCAPE_PAD.x, hp.z - ESCAPE_PAD.z).length() < 1.6 and absf(hp.y - ESCAPE_PAD.y) < 1.2:
			game.start_launch(h, ESCAPE_TO)
			var first: bool = rescue == "freed"
			rescue = "escort"
			if first:
				game.get_tree().create_timer(1.6).timeout.connect(spawn_ambush)
			game.get_tree().create_timer(0.6).timeout.connect(func() -> void:
				if is_instance_valid(game.ally) and game.ally.global_position.y < 130.0:
					game.ally.global_position = ESCAPE_TO + Vector3(1.8, 0.4, 1.2)
					game.ally.velocity = Vector3.ZERO
					game.burst(game.ally.global_position + Vector3.UP, Color("bfe9ff"), 20, 4.0))
			return
	if rescue != "escort":
		return
	var a: CharacterBody3D = game.ally
	var near_safe: bool = Vector2(hp.x - SAFE.x, hp.z - SAFE.z).length() < 2.6 and absf(hp.y - SAFE.y) < 2.0
	var ally_ok: bool = a.global_position.distance_to(SAFE) < 6.0
	var foes: bool = false
	for e: CharacterBody3D in ambush:
		if is_instance_valid(e) and e.alive():
			foes = true
	if near_safe and foes:
		game.say_once("ambush_left", "ally", "They're still on us! Drive them off first!")
	safe_t = safe_t + dt if near_safe and ally_ok and not foes else 0.0
	if safe_t > 0.6:
		rescue = "safe"
		game.hud.popup("SAFE", Color("7dffcf"))
		game.say("ally", "We made it. Thank you, Lance.")
		game.get_tree().create_timer(1.6).timeout.connect(func() -> void:
			game.mode = "win"
			game.sound("win", -4)
			game.hud.release())

func spawn_ambush() -> void:
	## Two knights try to stop the escape on the crown.
	if rescue != "escort":
		return
	game.say("ally", "More of them! Don't let them take me back!")
	for p: Vector3 in [Vector3(-3.0, 139.3, 15.0), Vector3(3.5, 139.3, 9.0)]:
		var k: Dictionary = {"pos": [p.x, p.y, p.z], "sec": last}
		summon(k)
		var e: CharacterBody3D = game.enemies.back()
		e.max_hp = 50
		e.hp = 50
		ambush.append(e)
		game.wake(e)
