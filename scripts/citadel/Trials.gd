extends RefCounted
## TRAINING: a movement test course for the traversal system (Traverse.gd).
## Flat sprint lane with small obstacles, smooth ledges (catch / shimmy / pull-up,
## can't be climbed), a climbing wall, a climbable tower, stepping platforms,
## a walkable ramp and a steep slide slope, a tall glide tower with a ladder,
## and three training knights to check combat after traversal.
## Open it from the title (TRAINING card) or with ?trials on the web build.

const SECTIONS: Array = [
	{"goal": "Training: sprint, climb, glide", "spawn": Vector3(0, 0.2, 6.0)},
]
const MAP_ZONES: Array = [Rect2(-36, -98, 72, 112)]

## Course landmarks (used by the autotest and the signs).
const LEDGE_LOW: Vector3 = Vector3(-10, 0, -4)      # smooth block 2.6 m high: jump, catch and vault up
const LEDGE_LOW_H: float = 2.6
const LEDGE_HIGH: Vector3 = Vector3(-10, 0, -14)    # smooth wall 3.3 m high, 8 m wide: hang + shimmy
const LEDGE_HIGH_H: float = 3.3
const CLIMB_WALL: Vector3 = Vector3(-22, 0, -10)    # climbable stone wall 9 m high
const CLIMB_WALL_H: float = 9.0
const TOWER: Vector3 = Vector3(18, 0, -12)          # climbable tower 6x6, 14 m
const TOWER_H: float = 14.0
const RAMP_BASE: Vector3 = Vector3(-14, 0, -40)     # 18 deg ramp up to a 4 m deck
const SLIDE_TOP: Vector3 = Vector3(14, 0, -40)      # 42 deg slide slope from a 6 m deck
const SLIDE_H: float = 6.0
const GLIDE_TOWER: Vector3 = Vector3(0, 0, -62)     # 3x3 pillar, 22 m, ladder on the south face
const GLIDE_H: float = 22.0
const TARGETS: Array = [Vector3(-6, 0.2, -82), Vector3(0, 0.2, -86), Vector3(6, 0.2, -82)]

var game: Node
var root: Node3D
var smooth: StandardMaterial3D

func _init(g: Node) -> void:
	game = g

func build() -> void:
	game.sections = SECTIONS
	game.map_zones = MAP_ZONES
	game.win_text = "TRAINING DONE"
	game.boss_name = ""
	game.citadel_look()
	game.env_res.fog_density = 0.0012
	root = Node3D.new()
	root.name = "Trials"
	game.world.add_child(root)
	smooth = StandardMaterial3D.new()
	smooth.albedo_color = Color("5d7f95")
	smooth.metallic = 0.2
	smooth.roughness = 0.12
	# ground
	game.box(Vector3(0, -0.5, -42), Vector3(76, 1.0, 116), "marble", true, root)
	# sprint lane markings + small obstacles to hop
	for z: float in [-2.0, -12.0, -22.0, -32.0]:
		game.box(Vector3(0, 0.01, z), Vector3(3.0, 0.02, 0.25), "gold", false, root)
	for c: Array in [[Vector3(4, 0.25, -4), 0.5], [Vector3(4, 0.45, -9), 0.9], [Vector3(4, 0.65, -14), 1.3], [Vector3(5.5, 0.3, -20), 0.6]]:
		var h: float = c[1]
		var p: Vector3 = c[0]
		game.box(Vector3(p.x, h * 0.5, p.z), Vector3(1.2, h, 1.2), "wood", true, root)
	put_sign(Vector3(0, 0, 1.5), "SPRINT LANE  (hold CTRL / tap SPRINT)")
	# smooth ledges: they can't be climbed, only caught
	smooth_block(LEDGE_LOW + Vector3(0, LEDGE_LOW_H * 0.5, 0), Vector3(3.0, LEDGE_LOW_H, 3.0))
	smooth_block(LEDGE_HIGH + Vector3(0, LEDGE_HIGH_H * 0.5, 0), Vector3(3.0, LEDGE_HIGH_H, 8.0))
	put_sign(LEDGE_LOW + Vector3(2.6, 0, 1.0), "LEDGES  (jump at them, shimmy, climb up)")
	# climbing wall
	game.box(CLIMB_WALL + Vector3(0, CLIMB_WALL_H * 0.5, 0), Vector3(3.0, CLIMB_WALL_H, 10.0), "stone", true, root)
	put_sign(CLIMB_WALL + Vector3(3.0, 0, 5.5), "CLIMBING WALL")
	# climbable tower with a top deck
	game.box(TOWER + Vector3(0, TOWER_H * 0.5, 0), Vector3(6.0, TOWER_H, 6.0), "stone", true, root)
	game.box(TOWER + Vector3(0, TOWER_H + 0.15, 0), Vector3(6.0, 0.3, 6.0), "gold", true, root)
	put_sign(TOWER + Vector3(-3.8, 0, 3.8), "CLIMB TOWER  14 m")
	# stepping platforms
	var hs: Array = [0.8, 1.6, 2.4, 3.2, 4.0]
	for i in hs.size():
		var h2: float = hs[i]
		game.box(Vector3(8 + i * 0.0, h2 * 0.5, -24 - i * 3.2), Vector3(2.4, h2, 2.4), "stone", true, root)
	put_sign(Vector3(8, 0, -21.5), "PLATFORMS")
	# walkable ramp up to a deck
	ramp(RAMP_BASE, 4.0, 18.0, 5.0, "marble")
	# steep slope from a high deck: you slide down it
	slide_hill()
	# glide tower with a ladder
	game.box(GLIDE_TOWER + Vector3(0, GLIDE_H * 0.5, 0), Vector3(3.0, GLIDE_H, 3.0), "stone", true, root)
	game.box(GLIDE_TOWER + Vector3(0, GLIDE_H + 0.2, 0), Vector3(7.0, 0.4, 7.0), "gold", true, root)
	ladder(GLIDE_TOWER + Vector3(0, 0, 2.2), GLIDE_TOWER + Vector3(0, GLIDE_H + 0.4, 1.2), Vector3(0, 0, -1))
	put_sign(GLIDE_TOWER + Vector3(2.4, 0, 3.0), "GLIDE TOWER  22 m  (ladder)")
	put_sign(Vector3(0, 0, -76), "TRAINING KNIGHTS")
	# lights so the course reads at a glance
	for p2: Vector3 in [Vector3(0, 6, -10), Vector3(0, 6, -45), Vector3(0, 6, -80)]:
		var l: OmniLight3D = OmniLight3D.new()
		l.position = p2
		l.omni_range = 26.0
		l.light_energy = 0.6
		l.light_color = Color("ffe8c0")
		root.add_child(l)

func smooth_block(pos: Vector3, size: Vector3) -> void:
	var mi: MeshInstance3D = game.box(pos, size, "stone", true, root)
	mi.material_override = smooth
	# a gold lip marks the edge you can grab
	game.box(pos + Vector3(0, size.y * 0.5 + 0.02, 0), Vector3(size.x + 0.08, 0.06, size.z + 0.08), "gold", false, root)
	for c: Node in mi.get_children():
		if c is StaticBody3D:
			c.add_to_group("noclimb")

## A ramp from base (bottom edge centre, rising toward -z) up to height h.
func ramp(base: Vector3, h: float, deg: float, width: float, material: String) -> void:
	var a: float = deg_to_rad(deg)
	var run: float = h / tan(a)
	var length: float = h / sin(a)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(width, 0.4, length)
	mi.mesh = bm
	mi.material_override = game.mat(material)
	mi.position = base + Vector3(0, h * 0.5 - 0.2 * cos(a), -run * 0.5)
	mi.rotation.x = a
	root.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	# the deck at the top
	game.box(base + Vector3(0, h * 0.5, -run - 2.5), Vector3(width, h, 5.0), material, true, root)

func slide_hill() -> void:
	## A deck SLIDE_H high (reached by a ladder); its +z side is a 42 degree slope.
	var top: Vector3 = SLIDE_TOP
	game.box(top + Vector3(0, SLIDE_H * 0.5, -2.5), Vector3(5.0, SLIDE_H, 5.0), "stone", true, root)
	ladder(top + Vector3(0, 0, -5.9), top + Vector3(0, SLIDE_H + 0.05, -4.2), Vector3(0, 0, 1))
	var a: float = deg_to_rad(42.0)
	var run: float = SLIDE_H / tan(a)
	var length: float = SLIDE_H / sin(a)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(5.0, 0.4, length)
	mi.mesh = bm
	mi.material_override = game.mat("marble")
	mi.position = top + Vector3(0, SLIDE_H * 0.5 - 0.2 * cos(a), run * 0.5)
	mi.rotation.x = a
	root.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	mi.add_child(body)
	put_sign(top + Vector3(3.2, 0, run + 1.0), "SLIDE SLOPE  42°")
	put_sign(RAMP_BASE + Vector3(-3.2, 0, 1.0), "RAMP  18°")

func ladder(bottom: Vector3, top: Vector3, face: Vector3) -> void:
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
	game.ladders.append({"bottom": bottom, "top": top, "face": face})

func put_sign(at: Vector3, label: String) -> void:
	var post: MeshInstance3D = game.box(at + Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), "wood", false, root)
	post.name = "SignPost"
	var t: Label3D = Label3D.new()
	t.text = label
	t.font_size = 44
	t.outline_size = 10
	t.modulate = Color("f4e3b0")
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.position = at + Vector3(0, 2.2, 0)
	t.pixel_size = 0.006
	root.add_child(t)

func spawn_cast() -> void:
	var h: Dictionary = game.HEROES[game.hero_key]
	var s0: Vector3 = SECTIONS[0].spawn
	game.hero = game.make_fighter("hero", h.model, 1.8, h.blade, 1.25, s0)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.hero.yaw = 0.0
	game.cam_yaw = 0.0
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, s0 + Vector3(2.4, 0, 1.6))
	game.ally.rig.sword.visible = false
	game.boss = null
	for p: Vector3 in TARGETS:
		var e: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, p)
		e.section = 0
		e.max_hp = 70
		e.hp = 70
		e.dmg = 4
		e.yaw = 0.0
		e.home = p
		game.enemies.append(e)

func start() -> void:
	game.say_once("trials_start", "tip", "Training course: sprint lane, ledges, climbing wall, tower, slopes and a glide tower.")
	game.say_once("trials_keys", "tip", "Jump in the air to GLIDE. DODGE drops off walls. Stamina is shared: rest on the ground.")

func progress() -> void:
	pass

func fall_line() -> float:
	return -9.0
