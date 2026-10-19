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
const PLATFORM: String = "res://assets/ruin3/hover_platform.glb"
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
	var pscene: PackedScene = load(PLATFORM)
	var padscene: PackedScene = load(PAD)
	var i: int = 0
	for pd: Dictionary in route.platforms:
		var base: Vector3 = v3(pd.pos)
		var body: AnimatableBody3D = AnimatableBody3D.new()
		body.sync_to_physics = true
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: CylinderShape3D = CylinderShape3D.new()
		sh.radius = 2.0
		sh.height = 0.6
		cs.shape = sh
		cs.position = Vector3(0, -0.3, 0)
		body.add_child(cs)
		var mesh: Node3D = pscene.instantiate()
		body.add_child(mesh)
		root.add_child(body)
		body.global_position = base
		var rec: Dictionary = {"body": body, "base": base, "phase": float(i) * 0.9}
		plats.append(rec)
		if pd.get("pad") != null:
			var pad: Node3D = padscene.instantiate()
			body.add_child(pad)
			pad.position = Vector3(0, 0.02, 0)
			pads.append({"plat": rec, "node": pad, "to": v3(pd.pad.to), "unlock": pd.pad.unlock, "active": false})
		i += 1

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
	game.say_once("ruin_start", "ally", "The citadel... the Dark Knight waits in the Core, under the crown.")
	game.say_once("ruin_tip", "tip", "Three ways up: the outer ledges, the tower inside, or the floating platforms.")

func progress() -> void:
	platforms_tick(game.get_process_delta_time())
	spawn_nearby()
	if game.section < last and game.section_clear(game.section):
		game.open_barrier(game.section)
		game.section += 1
		match game.section:
			1:
				game.say("ally", "The way's open. Ledges to the right, the tower door ahead, or the floating stones!")
			2:
				game.say("ally", "Ring 2 is ours. On to the Core Floor.")
			3:
				game.say("ally", "Up the sky stair to the crown!")
			4:
				game.say("ally", "The eye is open. Jump down. He's in the Core!")
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
		game.say("ally", "We can break through! Keep pressing!")

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
