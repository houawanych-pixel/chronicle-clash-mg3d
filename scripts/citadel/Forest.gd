extends RefCounted
## Forest Escape: Lance has just freed Eliza and the two of them sneak out
## through a forest while knights patrol in pairs and Blonde Lance hunts them.
## A designed path of three areas: tall grass hides you when you crouch,
## boulders and trees are hard cover (wall hug works on them). Getting spotted
## brings two more knights in from behind. Blonde Lance sweeps the grass,
## breaks off when hurt and turns up again further on.
const SECTIONS: Array = [
	{"goal": "Sneak through the glade", "spawn": Vector3(0, 0.2, -2.0)},
	{"goal": "Slip past the rocks", "spawn": Vector3(0, 0.2, -42.0)},
	{"goal": "Cross the tall grass", "spawn": Vector3(0, 0.2, -74.0)},
	{"goal": "Escape the forest", "spawn": Vector3(0, 0.2, -104.0)},
]
const MAP_ZONES: Array = [Rect2(-15, -112, 30, 118)]
const EXIT_Z: float = -110.0
const HALF_W: float = 14.0
## Grass patches (x, z, width, depth). Crouch or crawl inside to go hidden.
const GRASS: Array = [
	Rect2(-12.5, -38, 7.5, 26), Rect2(4, -16, 7, 5),
	Rect2(-13, -66, 6, 12), Rect2(7, -60, 6, 9),
	Rect2(-6, -101, 12, 20), Rect2(-13.5, -92, 5, 10), Rect2(9, -100, 4.5, 12),
]
## Boulders: position, radius. Radius 1.1+ is tall cover, smaller is low cover.
const ROCKS: Array = [
	[Vector3(-1.5, 0, -17), 1.3], [Vector3(6.5, 0, -33), 1.2], [Vector3(-3.0, 0, -40), 0.8],
	[Vector3(-6, 0, -48), 1.3], [Vector3(0.5, 0, -52), 1.0], [Vector3(6, 0, -49), 1.4],
	[Vector3(-3.5, 0, -58), 1.2], [Vector3(5, 0, -64), 1.1], [Vector3(-0.5, 0, -67), 0.8],
	[Vector3(-9.5, 0, -78), 1.2], [Vector3(9.5, 0, -80), 1.3], [Vector3(2, 0, -106), 0.9],
]
## Knight pairs: [area, route]
const PATROLS: Array = [
	[0, [Vector2(-2, -23), Vector2(10, -23)]],
	[0, [Vector2(3, -36), Vector2(3, -14)]],
	[1, [Vector2(-9, -54), Vector2(9, -54)]],
	[1, [Vector2(2, -71), Vector2(2, -57)]],
	[2, [Vector2(-11, -85), Vector2(11, -85)]],
	[2, [Vector2(11, -97), Vector2(-11, -93)]],
]
## Where Blonde Lance hunts in each area (he sweeps along the grass).
const HUNTS: Array = [
	[Vector2(-10, -46), Vector2(-10, -64), Vector2(10, -62), Vector2(10, -46)],
	[Vector2(-8, -100), Vector2(8, -100), Vector2(8, -86), Vector2(-8, -86)],
	[Vector2(0, -108), Vector2(-6, -104), Vector2(6, -104)],
]

var game: Node
var hunter: CharacterBody3D
var hunt_index: int = 0
var lost_t: Dictionary = {}
var reinforced: Dictionary = {}
var thresholds: Array = [0.66, 0.33, 0.1]
var escaped: bool = false

func _init(g: Node) -> void:
	game = g

# ---------------------------------------------------------------- world

func mat(id: String) -> StandardMaterial3D:
	if game.mats.has(id):
		return game.mats[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	match id:
		"forestfloor":
			var n: FastNoiseLite = FastNoiseLite.new()
			n.frequency = 0.03
			n.fractal_octaves = 4
			var img: Image = n.get_seamless_image(256, 256)
			img.convert(Image.FORMAT_RGB8)
			for y in 256:
				for x in 256:
					var v: float = img.get_pixel(x, y).r
					img.set_pixel(x, y, Color("3d5a2a").lerp(Color("6b5a3a"), clampf(v * 1.4 - 0.2, 0, 1)))
			img.generate_mipmaps()
			m.albedo_texture = ImageTexture.create_from_image(img)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.12, 0.12, 0.12)
			m.roughness = 0.95
		"bark":
			m.albedo_color = Color("4a3526")
			m.roughness = 0.95
		"leaves":
			m.albedo_color = Color("2f5a2c")
			m.roughness = 0.9
		"leaves2":
			m.albedo_color = Color("3d6e33")
			m.roughness = 0.9
		"boulder":
			m.albedo_color = Color("8a8d86")
			m.roughness = 0.9
		"moss":
			m.albedo_color = Color("5d7d3a")
			m.roughness = 0.95
		"grass":
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color.WHITE
			m.roughness = 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glow":
			m.albedo_color = Color(0.6, 1.0, 0.75, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("7dffcf")
			m.emission_energy_multiplier = 1.4
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	game.mats[id] = m
	return m

func wall(pos: Vector3, size: Vector3) -> void:
	## Invisible blocker for the forest edge.
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	game.world.add_child(body)

## Trees are batched into four MultiMeshes (trunk + three leaf cones):
## the same look as separate meshes, but a handful of draw calls instead of ~700.
var tree_parts: Array = [[], [], [], []]

func tree(pos: Vector3, h: float, collide: bool) -> void:
	tree_parts[0].append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, h * 0.55, 1)), pos + Vector3(0, h * 0.275, 0)))
	for i in 3:
		var r: float = h * (0.34 - i * 0.07)
		tree_parts[i + 1].append(Transform3D(Basis.IDENTITY.scaled(Vector3(r, h * 0.38, r)), pos + Vector3(0, h * (0.5 + i * 0.17), 0)))
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: CylinderShape3D = CylinderShape3D.new()
		sh.radius = 0.45
		sh.height = h * 0.55
		cs.shape = sh
		body.add_child(cs)
		body.position = pos + Vector3(0, h * 0.275, 0)
		game.world.add_child(body)
		game.add_wall(Rect2(pos.x - 0.45, pos.z - 0.45, 0.9, 0.9), h * 0.55)

func flush_trees() -> void:
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = 0.28
	trunk.bottom_radius = 0.42
	trunk.height = 1.0
	trunk.radial_segments = 7
	var meshes: Array = [trunk]
	for i in 3:
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.0
		cone.height = 1.0
		cone.radial_segments = 8
		meshes.append(cone)
	var mats: Array = [mat("bark"), mat("leaves"), mat("leaves2"), mat("leaves")]
	for k in 4:
		var list: Array = tree_parts[k]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats[k]
		if game.phone:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.world.add_child(mmi)
	tree_parts = [[], [], [], []]

func boulder(pos: Vector3, r: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.6
	sm.radial_segments = 9
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat("boulder")
	mi.position = pos + Vector3(0, r * 0.62, 0)
	mi.rotation.y = pos.x * 1.7
	mi.scale = Vector3(1.15, 1.0, 0.95)
	game.world.add_child(mi)
	var moss: MeshInstance3D = MeshInstance3D.new()
	var ms: SphereMesh = SphereMesh.new()
	ms.radius = r * 0.7
	ms.height = r * 0.5
	moss.mesh = ms
	moss.material_override = mat("moss")
	moss.position = pos + Vector3(0.1, r * 1.32, 0)
	game.world.add_child(moss)
	# Square footprint so wall hug and line of sight treat it like the MG crates.
	var s: float = r * 1.6
	var top: float = r * 1.45
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(s, top, s)
	cs.shape = sh
	cs.position = Vector3(0, top * 0.5, 0)
	body.add_child(cs)
	body.position = pos
	game.world.add_child(body)
	game.add_wall(Rect2(pos.x - s * 0.5, pos.z - s * 0.5, s, s), top)

func grass_patch(r: Rect2, mm_data: Array) -> void:
	var area: float = r.size.x * r.size.y
	var count: int = int(area * (4.5 if game.phone else 7.0))
	for i in count:
		var x: float = r.position.x + randf() * r.size.x
		var z: float = r.position.y + randf() * r.size.y
		mm_data.append([Vector3(x, 0, z), randf() * TAU, randf_range(0.85, 1.35), Color("4f7f2e").lerp(Color("9fb04a"), randf() * 0.7)])

func build() -> void:
	seed(11)
	var e: Environment = game.env_res
	var sm: ProceduralSkyMaterial = e.sky.sky_material
	sm.sky_top_color = Color("3a6aa8")
	sm.sky_horizon_color = Color("b9d6c4")
	sm.ground_horizon_color = Color("b9d6c4")
	sm.ground_bottom_color = Color("2b3a22")
	e.fog_light_color = Color("a9c7a6")
	e.fog_density = 0.012
	e.ambient_light_color = Color("a7c2a0")
	e.ambient_light_energy = 0.6
	e.tonemap_exposure = 0.82
	game.sun.light_energy = 1.15
	game.sun.light_color = Color("ffe6b8")
	game.sun.rotation_degrees = Vector3(-48, 35, 0)
	game.box(Vector3(0, -0.5, -52), Vector3(44, 1, 124), "marble", true).material_override = mat("forestfloor")
	wall(Vector3(-HALF_W - 0.5, 3, -52), Vector3(1, 6, 124))
	wall(Vector3(HALF_W + 0.5, 3, -52), Vector3(1, 6, 124))
	wall(Vector3(0, 3, 6.5), Vector3(30, 6, 1))
	# Dense tree lines on both edges and a ring of distant trees.
	var z: float = 6.0
	while z > -118.0:
		for side: float in [-1.0, 1.0]:
			tree(Vector3(side * randf_range(14.5, 16.5), 0, z + randf_range(-1, 1)), randf_range(9, 13), false)
			tree(Vector3(side * randf_range(18, 24), 0, z + randf_range(-2, 2)), randf_range(10, 15), false)
		z -= 3.2
	for i in 18:
		tree(Vector3(randf_range(-30, 30), 0, randf_range(-125, -116)), randf_range(10, 16), false)
	# Scattered trees inside the path: hard cover.
	for p: Vector2 in [Vector2(10.5, -12), Vector2(-9, -44), Vector2(11, -70), Vector2(-11.5, -100), Vector2(-4, -82), Vector2(5, -90)]:
		tree(Vector3(p.x, 0, p.y), randf_range(8, 11), true)
	flush_trees()
	for r: Array in ROCKS:
		boulder(r[0], r[1])
	# Tall grass as one multimesh of blades.
	var blades: Array = []
	for g: Rect2 in GRASS:
		game.grass.append(g)
		grass_patch(g, blades)
	var blade: PrismMesh = PrismMesh.new()
	blade.size = Vector3(0.14, 1.0, 0.02)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = blades.size()
	for i in blades.size():
		var b: Array = blades[i]
		var basis: Basis = Basis(Vector3.UP, b[1]).scaled(Vector3(1, b[2], 1))
		basis = basis.rotated(Vector3(1, 0, 0), randf_range(-0.15, 0.15))
		mm.set_instance_transform(i, Transform3D(basis, (b[0] as Vector3) + Vector3(0, b[2] * 0.5, 0)))
		mm.set_instance_color(i, b[3])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat("grass")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.world.add_child(mmi)
	# Exit: light between the trees.
	var exit_mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(10, 6)
	exit_mi.mesh = q
	exit_mi.material_override = mat("glow")
	exit_mi.position = Vector3(0, 3, EXIT_Z - 1.5)
	game.world.add_child(exit_mi)

# ---------------------------------------------------------------- cast

func spawn_cast() -> void:
	hunt_index = 0
	lost_t.clear()
	reinforced.clear()
	escaped = false
	thresholds = [0.66, 0.33, 0.1]
	var hero_def: Dictionary = game.HEROES["lance"]
	game.hero = game.make_fighter("hero", hero_def.model, 1.8, hero_def.blade, 1.25, SECTIONS[0].spawn)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, SECTIONS[0].spawn + Vector3(0.8, 0, 1.6))
	game.ally.rig.sword.visible = false
	game.ally.max_hp = 120
	game.ally.hp = 120
	for p: Array in PATROLS:
		var route: Array = p[1]
		var start: Vector2 = route[0]
		var k: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, Vector3(start.x, 0.2, start.y))
		k.section = p[0]
		k.max_hp = 70
		k.hp = 70
		k.home = k.global_position
		game.enemies.append(k)
		game.patrol.setup(k, route)
	hunter = game.make_fighter("hunter", game.HEROES["blonde_lance"].model, 1.85, Color("ffd27a"), 1.1, Vector3(-10, 0.2, -46))
	hunter.max_hp = 260
	hunter.hp = 260
	hunter.dmg = 15
	hunter.move_speed = 5.4
	hunter.reach = 2.6
	hunter.section = 1
	hunter.vision_range = 12.0
	hunter.vision_half = 50.0
	hunter.home = hunter.global_position
	game.enemies.append(hunter)
	game.patrol.setup(hunter, HUNTS[0])
	game.boss = hunter
	game.boss_name = "BLONDE LANCE"

func start() -> void:
	game.say("ally", "You came for me... They're already searching. Stay low!")
	game.say_once("forest_tip", "tip", "Crouch in tall grass to vanish. Rocks are cover. Keep her close.")

# ---------------------------------------------------------------- loop

func area_of(z: float) -> int:
	if z < -102.0:
		return 3
	if z < -72.0:
		return 2
	if z < -41.0:
		return 1
	return 0

func progress() -> void:
	var hero: CharacterBody3D = game.hero
	var a: int = area_of(hero.global_position.z)
	if a > game.section:
		game.section = a
		game.checkpoint = a
		match a:
			1:
				game.say("ally", "Rocks ahead. Wait for the guards to turn.")
			2:
				game.say("ally", "Into the tall grass. I'll stay right behind you.")
			3:
				game.say("ally", "I see the edge of the forest!")
	if not game.boss_seen and hero.global_position.z < -42.0:
		game.boss_seen = true
		game.say("hunter", "Lance! You think you can steal her from us? I'll find you.")
	if not escaped and hero.global_position.z < EXIT_Z and hero.alive():
		escaped = true
		game.hud.popup("ESCAPED!", Color("7dffcf"))
		game.say("ally", "We made it out... thank you, Lance.")
		game.get_tree().create_timer(1.6).timeout.connect(func() -> void:
			game.mode = "win"
			game.sound("win", -4)
			game.hud.release())

func on_alarm(e: CharacterBody3D) -> void:
	## Spotted: two more knights close in from behind, once per area.
	var a: int = area_of(game.hero.global_position.z)
	if reinforced.has(a):
		return
	reinforced[a] = true
	var z: float = game.hero.global_position.z + 13.0
	for x: float in [-3.0, 3.0]:
		var k: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, Vector3(x, 0.2, minf(z, 4.0)))
		k.section = a
		k.max_hp = 60
		k.hp = 60
		k.home = k.global_position
		k.stealth = true
		k.route = [Vector2(x, minf(z, 4.0))]
		k.gstate = "CHASE"
		k.active = true
		k.set_meta("reinforcement", true)
		k.yaw = 0.0
		game.enemies.append(k)
	game.say_once("reinforce%d" % a, "ally", "More of them behind us!")

func tick(dt: float) -> void:
	## Lost-contact rule from the MG guards (CHASE -> INVESTIGATE when they
	## lose you): hide out of sight for a few seconds and they go back to patrol.
	for e: CharacterBody3D in game.enemies:
		if not e.alive() or not e.stealth or not e.active:
			lost_t.erase(e)
			continue
		var d: float = e.global_position.distance_to(game.hero.global_position)
		if game.patrol.can_see(e) or d < 2.5:
			lost_t[e] = 0.0
			continue
		lost_t[e] = float(lost_t.get(e, 0.0)) + dt
		if float(lost_t[e]) > (4.0 if e == hunter else 5.0):
			lost_t[e] = 0.0
			e.active = false
			e.state = "idle"
			e.gstate = "INVESTIGATE"
			e.search_t = 5.0
			e.suspicion = 0.4
			game.give_token(e)
			if e == hunter:
				game.say("hunter", "Where did you go?! I'll find you...")
	if hunter and hunter.alive() and hunter.visible:
		var frac: float = hunter.hp / hunter.max_hp
		if thresholds.size() > 0 and frac < thresholds[0]:
			thresholds.pop_front()
			hunter_break()

func hunter_break() -> void:
	## Blonde Lance breaks off when hurt and reappears further along.
	game.burst(hunter.global_position + Vector3.UP, Color("ffd27a"), 30, 6.0)
	game.sound("hook", -6)
	game.give_token(hunter)
	game.marks.erase(hunter)
	hunt_index += 1
	if thresholds.is_empty() or hunt_index >= HUNTS.size():
		game.hud.popup("BLONDE LANCE FLEES", Color("ffd27a"))
		game.say("hunter", "This isn't over, Lance!")
		hunter.visible = false
		hunter.set_physics_process(false)
		hunter.global_position = Vector3(0, -50, 0)
		return
	game.hud.popup("BLONDE LANCE RETREATS", Color("ffd27a"))
	game.say("hunter", "Tch... you won't get far with her!")
	var route: Array = HUNTS[hunt_index]
	var start: Vector2 = route[0]
	hunter.global_position = Vector3(start.x, 0.2, start.y)
	hunter.velocity = Vector3.ZERO
	hunter.active = false
	hunter.state = "idle"
	hunter.gstate = "PATROL"
	hunter.route = route
	hunter.route_i = 1
	hunter.suspicion = 0.0
	hunter.section = hunt_index + 1
