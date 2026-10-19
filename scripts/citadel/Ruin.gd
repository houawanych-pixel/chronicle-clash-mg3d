extends RefCounted
## The Sky Citadel, rebuilt inside the owner's floating sky ruin
## (assets/ruin/skyruin.glb, from Tripo "cc_skyruin04"). The climb winds in and
## out of the ruin's hollow centre: sky dock -> broken bridge -> porch -> ladder
## -> main deck -> ladder -> upper ring -> the Hollow Span across the middle ->
## back ring -> ladder -> the Core, where the Dark Knight waits.
##
## The ruin mesh is solid (walls and its own floors are walkable for side
## exploring), and the main route is laid with clean walkways, stairs, bridges
## and ladders at the ruin's real floor heights so it never has holes.
## Ruin space: metres, front of the ruin is +Z, the core floor is at y 52.5.

const MODEL: String = "res://assets/ruin/skyruin.glb"
const COLLIDER: String = "res://assets/ruin/skyruin_col.glb"
const MODEL_SCALE: float = 71.3766
const MODEL_OFFSET: Vector3 = Vector3(-0.0948, 34.9848, -0.1971)

const SECTIONS: Array = [
	{"goal": "Take out the dock guards", "spawn": Vector3(0, 26.3, 57.0)},
	{"goal": "Cross the broken bridge", "spawn": Vector3(0, 26.3, 45.0)},
	{"goal": "Climb to the main deck and clear it", "spawn": Vector3(0, 35.4, 10.2)},
	{"goal": "Cross the Hollow Span to the back ring", "spawn": Vector3(-6.0, 41.7, 5.6)},
	{"goal": "Enter the Core. Defeat the Dark Knight", "spawn": Vector3(-0.6, 44.7, -10.4)},
]
## Floors of the route (y) — used for checkpoints, falls and the map.
const DOCK_Y: float = 26.0
const PORCH_Y: float = 28.4
const DECK_Y: float = 35.05
const RING_Y: float = 41.3
const BACK_Y: float = 44.35
const CORE_Y: float = 52.5

var game: Node
var root: Node3D
## Volumes covered by route walkways ({xf, half}). The ruin's own collision is
## removed inside them so its lumpy floor never trips you on a clean walkway.
var clear_vols: Array = []

func _init(g: Node) -> void:
	game = g

func configure() -> void:
	game.sections = SECTIONS
	game.map_zones = [Rect2(-12, 44, 24, 16), Rect2(-2.5, 20, 5, 24), Rect2(-24, -16, 48, 36)]
	game.boss_name = "DARK KNIGHT"
	game.win_text = "CITADEL CLEARED"

# ---------------------------------------------------------------- build

func build() -> void:
	configure()
	root = Node3D.new()
	root.name = "SkyRuin"
	game.world.add_child(root)
	game.ladders.clear()
	clear_vols.clear()
	look()
	add_route()
	add_ruin()
	add_sky()

func look() -> void:
	game.citadel_look()
	game.env_res.fog_density = 0.0016
	game.env_res.tonemap_exposure = 0.7
	game.env_res.ambient_light_energy = 0.45
	game.sun.light_energy = 1.25
	game.sun.rotation_degrees = Vector3(-40, 38, 0)

func add_ruin() -> void:
	var ruin: Node3D = (load(MODEL) as PackedScene).instantiate()
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
	# Solid ruin: a lighter copy of the same shape, already in metres.
	var col_scene: Node3D = (load(COLLIDER) as PackedScene).instantiate()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RuinCollision"
	for mi: MeshInstance3D in col_scene.find_children("*", "MeshInstance3D", true, false):
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var keep: PackedVector3Array = PackedVector3Array()
		var inv: Array = []
		for v: Dictionary in clear_vols:
			inv.append([(v.xf as Transform3D).affine_inverse(), v.half])
		var i: int = 0
		while i < faces.size():
			var c: Vector3 = (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var drop: bool = false
			for e: Array in inv:
				var l: Vector3 = (e[0] as Transform3D) * c
				var hf: Vector3 = e[1]
				if absf(l.x) < hf.x and absf(l.y) < hf.y and absf(l.z) < hf.z:
					drop = true
					break
			if not drop:
				keep.append(faces[i])
				keep.append(faces[i + 1])
				keep.append(faces[i + 2])
			i += 3
		var cps: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		cps.set_faces(keep)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = cps
		body.add_child(shape)
	col_scene.free()
	root.add_child(body)

## Route pieces ----------------------------------------------------------

## Register the space just above and below a walkway surface (local frame xf,
## surface at local y 0) as "ours": the ruin's collision is cleared there.
func clear_over(xf: Transform3D, half_xz: Vector2) -> void:
	clear_vols.append({"xf": xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.2, 0)), "half": Vector3(half_xz.x + 0.1, 0.8, half_xz.y + 0.1)})

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

func barrier(pos: Vector3, size: Vector3) -> void:
	var b: MeshInstance3D = game.box(pos, size, "barrier", true, root)
	game.barriers.append(b)

func planter(p: Vector3) -> void:
	## Low hedge planter on the dock: cover for crouching (low wall).
	game.box(p + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.4), "marble", true, root)
	game.box(p + Vector3(0, 1.1, 0), Vector3(2.9, 0.5, 1.1), "hedge", false, root)
	var r: Rect2 = Rect2(p.x - 1.6, p.z - 0.7, 3.2, 1.4)
	game.walls.append(r)
	game.wall_heights[r] = 1.2

func add_route() -> void:
	# Section 0 — the sky dock in front of the ruin (stealth: guards patrol).
	slab(Vector3(0, DOCK_Y, 52), Vector3(24, 1.2, 16))
	game.box(Vector3(0, DOCK_Y - 3.0, 52), Vector3(18, 4, 12), "stone", false, root)
	for p: Vector3 in [Vector3(-6, DOCK_Y, 49), Vector3(6, DOCK_Y, 53), Vector3(-5, DOCK_Y, 56.5)]:
		planter(p)
	for x: float in [-11.0, 11.0]:
		for z: float in [46.0, 52.0, 58.0]:
			game.column(Vector3(x, DOCK_Y, z), 5.0, 0.45, true)
	game.crystal(Vector3(-9, DOCK_Y, 45.5), 0.9)
	game.crystal(Vector3(9, DOCK_Y, 45.5), 0.9)
	# Section 1 — the broken bridge up to the ruin's porch (two gaps to jump).
	bridge(44.0, 20.0, DOCK_Y, PORCH_Y, [[36.0, 33.4], [27.2, 24.6]])
	slab(Vector3(0, PORCH_Y, 17), Vector3(8, 0.6, 6.4))
	# Ladder 1: porch -> main deck (the front face of the deck block).
	ladder(Vector3(1.6, PORCH_Y, 14.1), Vector3(1.6, DECK_Y, 11.5), Vector3(0, 0, -1))
	# Section 2 — the main deck, a crescent across the front.
	slab(Vector3(0, DECK_Y, 9.0), Vector3(26, 0.5, 4.6))
	slab(Vector3(0, DECK_Y, 9.6), Vector3(7, 0.5, 5.6), false)
	slab(Vector3(-15, DECK_Y - 0.2, 2.5), Vector3(8.5, 0.5, 10), false)
	slab(Vector3(15, DECK_Y - 0.2, 2.5), Vector3(8.5, 0.5, 10), false)
	walk(Vector3(-11, DECK_Y, 8.0), Vector3(-13, DECK_Y - 0.2, 5.5), 3.0)
	walk(Vector3(11, DECK_Y, 8.0), Vector3(13, DECK_Y - 0.2, 5.5), 3.0)
	# Ladder 2: deck -> upper ring (the ring's front edge above the deck).
	ladder(Vector3(-6, DECK_Y, 10.6), Vector3(-6, RING_Y, 9.2), Vector3(0, 0, -1))
	# Section 3 — upper ring, then the Hollow Span through the middle to the back ring.
	slab(Vector3(-6, RING_Y, 8.0), Vector3(5, 0.5, 3.6))
	slab(Vector3(-3, RING_Y, 5.4), Vector3(10, 0.5, 2.8))
	walk(Vector3(0, RING_Y, 4.4), Vector3(-0.6, BACK_Y, -6.6), 3.0)
	walk(Vector3(-0.6, BACK_Y, -6.6), Vector3(-0.6, BACK_Y, -10.0), 2.6)
	slab(Vector3(-0.4, BACK_Y, -10.5), Vector3(6.4, 0.5, 2.4))
	# Section 4 — a short landing and Ladder 3 up into the Core.
	walk(Vector3(1.2, BACK_Y, -9.8), Vector3(1.2, BACK_Y, -7.4), 2.2)
	ladder(Vector3(1.2, BACK_Y, -7.0), Vector3(1.2, CORE_Y, -5.4), Vector3(0, 0, 1))
	slab(Vector3(0, CORE_Y, -1.0), Vector3(18, 0.5, 9.6))
	game.crystal(Vector3(-7.5, CORE_Y, 2.4), 1.3, true)
	game.crystal(Vector3(7.5, CORE_Y, 2.4), 1.3, true)
	# Barriers open as sections are cleared.
	barrier(Vector3(0, DOCK_Y + 2.0, 43.6), Vector3(5.2, 4.0, 0.4))
	barrier(Vector3(1.6, PORCH_Y + 2.0, 15.0), Vector3(2.2, 4.0, 0.4))
	barrier(Vector3(-6, DECK_Y + 2.0, 11.6), Vector3(2.2, 4.0, 0.4))
	barrier(Vector3(1.2, BACK_Y + 2.0, -8.1), Vector3(2.4, 4.0, 0.4))

func add_sky() -> void:
	for i in 14:
		var c: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(70, 70)
		c.mesh = q
		c.material_override = game.mat("cloud")
		c.rotation.x = -PI / 2.0
		c.position = Vector3(randf_range(-110, 110), -4.0 - i * 0.6, randf_range(-110, 110))
		root.add_child(c)
	var spots: Array = [Vector3(-70, 30, -40), Vector3(80, 38, -60), Vector3(-95, 52, 40), Vector3(100, 22, 50), Vector3(-50, 64, -110), Vector3(55, 46, -120), Vector3(-120, 28, -10), Vector3(125, 58, 0), Vector3(0, 80, -160), Vector3(-80, 12, 90), Vector3(85, 8, 110)]
	for i in spots.size():
		game.island(spots[i], 8.0 + float(i % 4) * 4.0)

# ---------------------------------------------------------------- cast

func spawn_cast() -> void:
	var h: Dictionary = game.HEROES[game.hero_key]
	game.hero = game.make_fighter("hero", h.model, 1.8, h.blade, 1.25, SECTIONS[0].spawn)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.hero.yaw = 0.0
	game.cam_yaw = 0.0
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, SECTIONS[0].spawn + Vector3(1.6, 0, 1.4))
	game.ally.rig.sword.visible = false
	var knights: Array = [
		[0, Vector3(-7, DOCK_Y + 0.2, 50)], [0, Vector3(7, DOCK_Y + 0.2, 47)], [0, Vector3(0, DOCK_Y + 0.2, 45.5)],
		[1, Vector3(0, 27.2, 30.5)], [1, Vector3(1.2, PORCH_Y + 0.2, 17.5)],
		[2, Vector3(-9, DECK_Y + 0.2, 9.0)], [2, Vector3(9, DECK_Y + 0.2, 9.0)], [2, Vector3(-15, DECK_Y, 2.5)], [2, Vector3(15, DECK_Y, 2.5)],
		[3, Vector3(-0.8, 42.8, -2.4)], [3, Vector3(1.6, BACK_Y + 0.2, -10.4)],
	]
	for k: Array in knights:
		var e: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, k[1])
		e.section = k[0]
		e.max_hp = 70
		e.hp = 70
		e.yaw = 0.0
		e.home = k[1]
		game.enemies.append(e)
	# Dock guards patrol with vision cones (stealth, from the MG guards).
	var routes: Array = [
		[Vector2(-7, 50), Vector2(3, 50)],
		[Vector2(7, 47), Vector2(7, 57), Vector2(1, 57), Vector2(1, 47)],
		[Vector2(0, 45.5), Vector2(-7, 46.5), Vector2(-2, 54)],
	]
	for i in routes.size():
		game.patrol.setup(game.enemies[i], routes[i])
	var boss: CharacterBody3D = game.make_fighter("boss", "res://assets/characters/knight.glb", 2.55, Color("ff3346"), 1.6, Vector3(0, CORE_Y + 0.2, 1.6))
	boss.section = 4
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

func start() -> void:
	game.say_once("ruin_start", "ally", "The citadel is a ruin now... the Dark Knight waits at its core.")
	game.say_once("ruin_tip", "tip", "Stay low behind the planters. Walk into a ladder and push forward to climb.")

# ---------------------------------------------------------------- progress

func progress() -> void:
	if game.section < 4 and game.section_clear(game.section):
		game.open_barrier(game.section)
		game.section += 1
		match game.section:
			1:
				game.say("ally", "The bridge is broken. Jump the gaps, and don't look down!")
			2:
				game.say("ally", "Up the ladder. The main deck is crawling with guards.")
			3:
				game.say("ally", "Another ladder. We go across the hollow from up there.")
			4:
				game.say("ally", "The Core is right above us. Ready?")
	var p: Vector3 = game.hero.global_position
	var reached: int = game.checkpoint
	for i in range(SECTIONS.size() - 1, 0, -1):
		var s: Vector3 = SECTIONS[i].spawn
		if p.y > s.y - 1.2 and Vector2(p.x - s.x, p.z - s.z).length() < 5.0:
			reached = maxi(reached, i)
			break
	if reached > game.checkpoint and reached <= game.section:
		game.checkpoint = reached
	if not game.boss_seen and p.y > CORE_Y - 1.0:
		game.boss_seen = true
		game.boss.active = true
		game.sound("alarm", -8)
		game.say("boss", "You climbed all this way to die in my core?")
		game.say("ally", "We can break through! Keep pressing!")

func fall_line() -> float:
	## Fell off the route: below the current checkpoint's floor by a good margin.
	return (SECTIONS[game.checkpoint].spawn as Vector3).y - 9.0

func in_core() -> bool:
	return game.hero != null and game.hero.global_position.y > CORE_Y - 1.0
