extends RefCounted
## The Sky Citadel: the owner's floating sky ruin (assets/ruin/skyruin.glb, from
## Tripo "cc_skyruin04") at twice its first size, about 140 m tall. The climb
## runs round the OUTSIDE of the ruin: sky dock -> broken bridge -> three rings
## of floating ledges with jumps between them, each ring ending at a ladder up
## to the next -> a sky stair spiralling up in front -> the crown on top ->
## drop through the eye into the Core, where the Dark Knight waits.
##
## The route is designed offline against the ruin's shape (tools in
## docs/RUIN_BUILD.md) and saved as assets/ruin/route.json: walkways, pads,
## ladders, gates, checkpoints, knights and the test bot's moves. The ruin's
## collision (skyruin_col.glb, already x2 and in metres) only keeps the walls
## near the route and the Core, so the game has far less to check every frame.

const MODEL: String = "res://assets/ruin/skyruin.glb"
const MODEL_LITE: String = "res://assets/ruin/skyruin_lite.glb"
const COLLIDER: String = "res://assets/ruin/skyruin_col.glb"
const ROUTE: String = "res://assets/ruin/route.json"
const MODEL_SCALE: float = 142.7533
const MODEL_OFFSET: Vector3 = Vector3(-0.1895, 69.9695, -0.3943)

var game: Node
var root: Node3D
var route: Dictionary = {}
var sections: Array = []
var core_y: float = 105.0
var crown_y: float = 139.0
var eye: Rect2 = Rect2()
var dock: Vector3 = Vector3.ZERO
## The last section: the Core and the boss.
var last: int = 6
var clear_vols: Array = []

func _init(g: Node) -> void:
	game = g
	load_route()

static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func load_route() -> void:
	var f: FileAccess = FileAccess.open(ROUTE, FileAccess.READ)
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

func configure() -> void:
	game.sections = sections
	game.map_zones = [Rect2(dock.x - 13, dock.z - 9, 26, 18), Rect2(-50, -50, 100, 100)]
	game.boss_name = "DARK KNIGHT"
	game.win_text = "CITADEL CLEARED"

# ---------------------------------------------------------------- build

func build() -> void:
	configure()
	root = Node3D.new()
	root.name = "SkyRuin"
	game.world.add_child(root)
	game.ladders.clear()
	look()
	add_route()
	add_ruin()
	add_sky()

func look() -> void:
	game.citadel_look()
	game.env_res.fog_density = 0.0009
	game.env_res.tonemap_exposure = 0.7
	game.env_res.ambient_light_energy = 0.45
	game.sun.light_energy = 1.25
	game.sun.rotation_degrees = Vector3(-40, 38, 0)
	if game.sun.shadow_enabled:
		game.sun.directional_shadow_max_distance = 60.0

func add_ruin() -> void:
	var ruin: Node3D = (load(MODEL_LITE if game.phone else MODEL) as PackedScene).instantiate()
	ruin.scale = Vector3.ONE * MODEL_SCALE
	ruin.position = MODEL_OFFSET
	root.add_child(ruin)
	# Warm the pale stone toward the ivory/gold look of the concept screens.
	for mi: MeshInstance3D in ruin.find_children("*", "MeshInstance3D", true, false):
		var src: Material = mi.mesh.surface_get_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			m.albedo_color = Color(0.86, 0.8, 0.71)
			m.roughness = 0.92
			mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if game.phone else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var col_scene: Node3D = (load(COLLIDER) as PackedScene).instantiate()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RuinCollision"
	for mi: MeshInstance3D in col_scene.find_children("*", "MeshInstance3D", true, false):
		var cps: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cps.set_faces(mi.mesh.get_faces())
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = cps
		body.add_child(shape)
	col_scene.free()
	root.add_child(body)

## Route pieces ----------------------------------------------------------

func clear_over(_xf: Transform3D, _half_xz: Vector2) -> void:
	pass   # the ruin floor under walkways is removed offline (col2.py)

func slab(center: Vector3, size: Vector3, trim: bool = true) -> void:
	## A walkway floor whose top surface is at center.y.
	clear_over(Transform3D(Basis.IDENTITY, center), Vector2(size.x * 0.5, size.z * 0.5))
	game.box(center - Vector3(0, size.y * 0.5, 0), size, "marble", true, root)
	if trim:
		for s: float in [-1.0, 1.0]:
			game.box(center + Vector3(s * (size.x * 0.5 - 0.06), 0.03, 0), Vector3(0.12, 0.08, size.z), "gold", false, root)

func walk(a: Vector3, b: Vector3, width: float = 3.0) -> void:
	## Straight walkway from a to b (floor points). Rises become steps over a hidden ramp.
	var flat: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z)
	var length: float = flat.length()
	var basis: Basis = Basis.looking_at(flat.normalized(), Vector3.UP) if length > 0.01 else Basis.IDENTITY
	var dy: float = b.y - a.y
	if absf(dy) < 0.25:
		var n: Node3D = Node3D.new()
		root.add_child(n)
		n.transform = Transform3D(basis, (a + b) * 0.5)
		clear_over(n.transform, Vector2(width * 0.5, length * 0.5 + 0.2))
		game.box(Vector3(0, -0.2, 0), Vector3(width, 0.4, length + 0.4), "marble", true, n)
		for s: float in [-1.0, 1.0]:
			game.box(Vector3(s * (width * 0.5 - 0.06), 0.03, 0), Vector3(0.12, 0.08, length + 0.4), "gold", false, n)
		return
	# Hidden ramp for walking (CharacterBody3D can't climb step edges)...
	var ramp_len: float = sqrt(length * length + dy * dy)
	var pitch: float = atan2(dy, length)
	var rb: StaticBody3D = StaticBody3D.new()
	var rs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(width, 0.3, ramp_len + 0.3)
	rs.shape = bs
	rb.add_child(rs)
	root.add_child(rb)
	rb.transform = Transform3D(basis * Basis(Vector3.RIGHT, pitch), (a + b) * 0.5 + Vector3(0, -0.15, 0))
	clear_over(Transform3D(rb.transform.basis, (a + b) * 0.5), Vector2(width * 0.5, ramp_len * 0.5))
	# ...and visible stone steps over it.
	var steps: int = maxi(2, int(ceil(absf(dy) / 0.24)))
	var n2: Node3D = Node3D.new()
	root.add_child(n2)
	n2.transform = Transform3D(basis, a)
	for i in steps:
		var t0: float = float(i) / steps
		var t1: float = float(i + 1) / steps
		var top: float = dy * t1 if dy > 0 else dy * t0
		var z0: float = -length * t0
		var z1: float = -length * t1
		var h: float = top - minf(0.0, dy) + 0.3
		game.box(Vector3(0, top - h * 0.5, (z0 + z1) * 0.5), Vector3(width, h, absf(z1 - z0) + 0.02), "marble", false, n2)
	for s: float in [-1.0, 1.0]:
		game.box(Vector3(s * (width * 0.5 + 0.08), dy * 0.5 + 0.45, -length * 0.5), Vector3(0.16, 0.9, length), "stone", false, n2)

func bridge(z0: float, z1: float, y0: float, y1: float, gaps: Array, width: float = 5.0) -> void:
	## Sky bridge along -Z from z0 to z1 with broken gaps (each [start, end] in z).
	var cuts: Array = [z0]
	for g: Array in gaps:
		cuts.append(g[0])
		cuts.append(g[1])
	cuts.append(z1)
	var i: int = 0
	while i < cuts.size() - 1:
		var za: float = cuts[i]
		var zb: float = cuts[i + 1]
		var ya: float = lerpf(y0, y1, (z0 - za) / (z0 - z1))
		var yb: float = lerpf(y0, y1, (z0 - zb) / (z0 - z1))
		walk(Vector3(0, ya, za), Vector3(0, yb, zb), width)
		var mid: float = (za + zb) * 0.5
		game.box(Vector3(0, (ya + yb) * 0.5 - 1.6, mid), Vector3(width - 1.4, 2.4, absf(zb - za) - 0.4), "stone", false, root)
		for s: float in [-1.0, 1.0]:
			var z: float = za - 1.5
			while z > zb + 1.0:
				var y: float = lerpf(ya, yb, (za - z) / (za - zb))
				game.box(Vector3(s * (width * 0.5 - 0.1), y + 0.6, z), Vector3(0.35, 1.2, 0.35), "gold", false, root)
				z -= 3.0
		i += 2

func ladder(bottom: Vector3, top: Vector3, face: Vector3) -> void:
	## bottom: the floor point at the foot of the ladder; top: where the climber
	## steps off; face: horizontal direction toward the wall.
	face = Vector3(face.x, 0, face.z).normalized()
	var side: Vector3 = face.cross(Vector3.UP).normalized()
	var h: float = top.y - bottom.y + 0.7
	var base: Vector3 = bottom + face * 0.25
	for s: float in [-0.42, 0.42]:
		var rail: MeshInstance3D = game.box(base + side * s + Vector3(0, h * 0.5, 0), Vector3(0.1, h, 0.1), "wood", false, root)
		rail.look_at(rail.global_position + face, Vector3.UP)
	var y: float = 0.35
	while y < h - 0.2:
		var rung: MeshInstance3D = game.box(base + Vector3(0, y, 0), Vector3(0.84, 0.07, 0.07), "wood", false, root)
		rung.look_at(rung.global_position + face, Vector3.UP)
		y += 0.38
	# A gold cap so the ladder reads from a distance.
	for s2: float in [-0.42, 0.42]:
		game.box(base + side * s2 + Vector3(0, h + 0.04, 0), Vector3(0.16, 0.08, 0.16), "gold", false, root)
	game.ladders.append({"bottom": bottom, "top": top, "face": face})

func barrier(pos: Vector3, size: Vector3, face: Vector3 = Vector3(0, 0, -1)) -> void:
	var b: MeshInstance3D = game.box(pos, size, "barrier", true, root)
	b.rotation.y = atan2(face.x, face.z)
	game.barriers.append(b)

func planter(p: Vector3) -> void:
	## Low hedge planter on the dock: cover for crouching (low wall).
	game.box(p + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.4), "marble", true, root)
	game.box(p + Vector3(0, 1.1, 0), Vector3(2.9, 0.5, 1.1), "hedge", false, root)
	var r: Rect2 = Rect2(p.x - 1.6, p.z - 0.7, 3.2, 1.4)
	game.walls.append(r)
	game.wall_heights[r] = 1.2

func pillar(base: Vector3, top: float, size: float) -> void:
	## Stone column standing in the sky, carrying a ladder up to the next ring.
	var h: float = top - 0.3 - base.y
	var r: float = size * 0.5
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.08
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = game.mat("stone")
	mi.position = Vector3(base.x, base.y + h * 0.5, base.z)
	root.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	# Broken rock root under it and gold bands up the shaft.
	var root_rock: MeshInstance3D = MeshInstance3D.new()
	var rc: CylinderMesh = CylinderMesh.new()
	rc.top_radius = r * 1.5
	rc.bottom_radius = 0.0
	rc.height = 5.0
	rc.radial_segments = 7
	root_rock.mesh = rc
	root_rock.material_override = game.mat("rock")
	root_rock.position = Vector3(base.x, base.y - 2.5, base.z)
	root.add_child(root_rock)
	var y: float = 3.0
	while y < h - 1.0:
		var band: MeshInstance3D = MeshInstance3D.new()
		var bc: CylinderMesh = CylinderMesh.new()
		bc.top_radius = r * 1.1
		bc.bottom_radius = r * 1.1
		bc.height = 0.22
		bc.radial_segments = 16
		band.mesh = bc
		band.material_override = game.mat("gold")
		band.position = Vector3(base.x, base.y + y, base.z)
		root.add_child(band)
		y += 4.0

func add_route() -> void:
	for p: Dictionary in route.pieces:
		match p.type:
			"slab":
				slab(v3(p.pos), v3(p.size), p.trim)
			"pad":
				if p.has("a"):
					walk(v3(p.a), v3(p.b), 5.0)
				else:
					slab(v3(p.pos), v3(p.size), false)
				# A floating rock under each wider pad.
				var c: Vector3 = v3(p.pos)
				game.box(c - Vector3(0, 1.4, 0), Vector3(3.6, 2.2, 3.6), "rock", false, root)
			"walk":
				walk(v3(p.a), v3(p.b), p.width)
			"pillar":
				pillar(v3(p.pos), p.top, p.size)
			"bridge":
				bridge(p.z0, p.z1, p.y0, p.y1, p.gaps)
			"dock_dressing":
				dock_dressing(v3(p.pos))
	for l: Dictionary in route.ladders:
		ladder(v3(l.bottom), v3(l.top), v3(l.face))
	for b: Variant in route.barriers:
		if b == null:
			game.barriers.append(null)   # a section with no gate
			continue
		barrier(v3(b.pos), v3(b.size), v3(b.face))
	game.crystal(Vector3(-4.5, crown_y, 11.0), 1.0, true)
	game.crystal(Vector3(4.5, crown_y, 11.0), 1.0, true)
	game.crystal(Vector3(-12, core_y, -2), 1.3, true)
	game.crystal(Vector3(12, core_y, -2), 1.3, true)

func dock_dressing(c: Vector3) -> void:
	game.box(c - Vector3(0, 3.0, 0), Vector3(18, 4, 12), "stone", false, root)
	for p: Vector3 in [Vector3(-6, 0, -3), Vector3(6, 0, 1), Vector3(-5, 0, 4.5)]:
		planter(c + p)
	for x: float in [-11.0, 11.0]:
		for z: float in [-6.0, 0.0, 6.0]:
			game.column(c + Vector3(x, 0, z), 5.0, 0.45, true)
	game.crystal(c + Vector3(-9, 0, -6.5), 0.9)
	game.crystal(c + Vector3(9, 0, -6.5), 0.9)

func add_sky() -> void:
	for i in 14:
		var c: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(110, 110)
		c.mesh = q
		c.material_override = game.mat("cloud")
		c.rotation.x = -PI / 2.0
		c.position = Vector3(randf_range(-170, 170), 20.0 - i * 0.6, randf_range(-170, 170))
		root.add_child(c)
	var spots: Array = [Vector3(-110, 50, -60), Vector3(120, 66, -80), Vector3(-140, 90, 50), Vector3(150, 40, 70), Vector3(-80, 110, -160), Vector3(85, 80, -170), Vector3(-170, 46, -10), Vector3(175, 100, 0), Vector3(0, 130, -220), Vector3(-120, 20, 140), Vector3(130, 14, 160)]
	for i in spots.size():
		game.island(spots[i], 10.0 + float(i % 4) * 5.0)

# ---------------------------------------------------------------- cast

func spawn_cast() -> void:
	var h: Dictionary = game.HEROES[game.hero_key]
	var s0: Vector3 = sections[0].spawn
	game.hero = game.make_fighter("hero", h.model, 1.8, h.blade, 1.25, s0)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.hero.yaw = 0.0
	game.cam_yaw = 0.0
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, s0 + Vector3(1.6, 0, 1.4))
	game.ally.rig.sword.visible = false
	var guards: Array = []
	pending.clear()
	for k: Dictionary in route.knights:
		# Only the first area's guards are made now; the rest appear when you get there.
		if int(k.sec) > 0:
			pending.append(k)
			continue
		var e: CharacterBody3D = make_knight(k)
		if k.get("patrol", false):
			guards.append(e)
	# Dock guards patrol with vision cones (stealth, from the MG guards).
	var routes: Array = guard_routes(guards)
	for i in mini(routes.size(), guards.size()):
		game.patrol.setup(guards[i], routes[i])
	var boss: CharacterBody3D = game.make_fighter("boss", "res://assets/characters/knight.glb", 2.55, Color("ff3346"), 1.6, boss_pos())
	boss.section = last
	boss.max_hp = 650
	boss.hp = 650
	boss.dmg = 18
	boss.reach = 3.1
	boss.move_speed = 4.2
	boss.yaw = 0.0
	boss.home = boss.global_position
	game.boss = boss
	game.enemies.append(boss)
	if not game.phone:
		var aura: OmniLight3D = OmniLight3D.new()
		aura.light_color = Color("ff3346")
		aura.light_energy = 1.6
		aura.omni_range = 5.0
		aura.position = Vector3(0, 2.0, 0)
		boss.add_child(aura)

func make_knight(k: Dictionary) -> CharacterBody3D:
	var p: Vector3 = v3(k.pos)
	var e: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, p)
	e.section = int(k.sec)
	e.max_hp = 70
	e.hp = 70
	e.yaw = 0.0
	e.home = p
	game.enemies.append(e)
	return e

## Knights waiting to appear: made when the hero reaches their area (saves work on phones).
var pending: Array = []
const SPAWN_RANGE: float = 30.0

func has_pending(sec: int) -> bool:
	for k: Dictionary in pending:
		if int(k.sec) == sec:
			return true
	return false

func clear_pending() -> void:
	pending.clear()

func spawn_nearby() -> void:
	if pending.is_empty() or game.hero == null:
		return
	var h: Vector3 = game.hero.global_position
	for k: Dictionary in pending.duplicate():
		var p: Vector3 = v3(k.pos)
		if (int(k.sec) <= game.section or k.get("free", false)) and absf(p.y - h.y) < 14.0 and Vector2(p.x - h.x, p.z - h.z).length() < SPAWN_RANGE:
			pending.erase(k)
			summon(k)

func summon(k: Dictionary) -> void:
	## A knight steps out of a flash of dark magic: violet burst, a ring on the floor, a short light pillar.
	var p: Vector3 = v3(k.pos)
	var e: CharacterBody3D = make_knight(k)
	e.visible = false
	e.attack_cd = 1.4
	game.burst(p + Vector3(0, 1.0, 0), Color("b06cff"), 30, 5.0)
	game.ring(p + Vector3(0, 0.05, 0), 2.2, Color("b06cff"), 0.6)
	var col: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.9
	cm.height = 4.0
	cm.radial_segments = 10
	col.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.7, 0.4, 1.0, 0.8)
	col.material_override = m
	root.add_child(col)
	col.global_position = p + Vector3(0, 2.0, 0)
	var tw: Tween = col.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.parallel().tween_property(col, "scale", Vector3(0.2, 1.3, 0.2), 0.7)
	tw.tween_callback(col.queue_free)
	game.sound("pulse", -10)
	game.get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(e):
			e.visible = true)

func guard_routes(_guards: Array) -> Array:
	var d: Vector2 = Vector2(dock.x, dock.z)
	return [
		[d + Vector2(-7, -2), d + Vector2(3, -2)],
		[d + Vector2(7, -5), d + Vector2(7, 5), d + Vector2(1, 5), d + Vector2(1, -5)],
		[d + Vector2(0, -6.5), d + Vector2(-7, -5.5), d + Vector2(-2, 2)],
	]

func boss_pos() -> Vector3:
	return Vector3(0, core_y + 0.2, -4.0)

# ---------------------------------------------------------------- progress

func start() -> void:
	game.say_once("ruin_start", "ally", "The citadel is a ruin now... the Dark Knight waits at its core, right at the top.")
	game.say_once("ruin_tip", "tip", "Stay low behind the planters. Jump the gaps, climb the ladders, run all the way round.")

func progress() -> void:
	spawn_nearby()
	if game.section < last and game.section_clear(game.section):
		game.open_barrier(game.section)
		game.section += 1
		match game.section:
			1:
				game.say("ally", "The bridge is broken. Jump the gaps, then follow the ledges round!")
			2:
				game.say("ally", "Up the ladder! The next ring goes round the far side.")
			3:
				game.say("ally", "Higher! Don't look down.")
			4:
				game.say("ally", "A sky stair. Keep jumping, all the way to the crown!")
			5:
				game.say("ally", "The eye is open. Jump down. He's in the Core!")
	var p: Vector3 = game.hero.global_position
	var reached: int = game.checkpoint
	for i in range(sections.size() - 1, 0, -1):
		var s: Vector3 = sections[i].spawn
		if p.y > s.y - 1.2 and p.y < s.y + 3.0 and Vector2(p.x - s.x, p.z - s.z).length() < 5.0:
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

func in_eye(p: Vector3) -> bool:
	return eye.grow(1.0).has_point(Vector2(p.x, p.z)) and p.y > core_y - 1.0

func fall_line() -> float:
	## Fell off the route: below the current checkpoint's floor by a good margin.
	## Dropping through the eye into the Core is the way in, not a fall.
	if game.section >= last - 1 and game.hero != null and in_eye(game.hero.global_position):
		return core_y - 9.0
	return (sections[game.checkpoint].spawn as Vector3).y - 9.0

func in_core() -> bool:
	if game.hero == null:
		return false
	var p: Vector3 = game.hero.global_position
	return p.y > core_y - 1.0 and p.y < core_y + 8.0 and absf(p.x) < 19.0 and absf(p.z + 2.0) < 12.0
