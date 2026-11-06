extends RefCounted
## ISLES: the island test world (owner's call, Nov 2026).
## Homelancer's breakable block ground (IsleBlocks.gd) at Lance size, islands built from scratch.
##   - The world is a 3 x 3 grid of 48 m tiles (144 m) that wraps round, Pac-Man style:
##     sail or walk off one edge and you come back on the other. The seam is open sea.
##   - Four islands with open ocean between them, and a boat to sail across.
##   - Weather by zone: sea fog round Mist Isle (a serpent hides in it, a chest waits on the isle),
##     a dust storm round Dune Isle (a chest is buried under the sand: bomb it out).
##   - Rocks break after a few sword hits (sand 1, dirt 2, stone 4, obsidian 8: darker = tougher);
##     bombs blast round craters and dig tunnels.
##   - You play Lance with his usual moves; ledges, climbing and the glider are on here too.
## Open it from the title (ISLES card) or with ?isles on the web build.

const IsleBlocks = preload("res://scripts/citadel/IsleBlocks.gd")
const SurvivalScript = preload("res://scripts/citadel/IslesSurvival.gd")
const FoliageScript = preload("res://scripts/citadel/IslesFoliage.gd")
const TILE: float = 48.0
const WORLD: float = 144.0
const HALF: float = 72.0

const ISLANDS: Array = [
	{"name": "HOME ISLE", "c": Vector2(0, 4), "r": 20.0, "h": 5.0, "style": 1, "rocks": 9, "dark": 0.1},
	{"name": "CRAG ISLE", "c": Vector2(48, -6), "r": 14.0, "h": 8.0, "style": 3, "rocks": 12, "dark": 0.55},
	{"name": "DUNE ISLE", "c": Vector2(-42, 34), "r": 15.0, "h": 3.0, "style": 2, "rocks": 1, "dark": 0.0},
	{"name": "MIST ISLE", "c": Vector2(-8, -48), "r": 12.0, "h": 6.0, "style": 1, "rocks": 5, "dark": 0.3},
	{"name": "GULL ROCK", "c": Vector2(44, 42), "r": 6.5, "h": 2.5, "style": 1, "rocks": 2, "dark": 0.0},
]
## Weather zones: [centre, radius, kind]
const ZONES: Array = [[Vector2(-8, -48), 34.0, "fog"], [Vector2(-42, 34), 30.0, "dust"]]
const BURIED: Vector2 = Vector2(-39, 31)          # the chest under Dune Isle's sand
const SWORD_POWER: int = 1
const BOMB_R: float = 1.9
const BOMB_POWER: int = 4
const BOMB_FUSE: float = 2.0
const BOAT_SPEED: float = 9.0
const DECK_Y: float = 0.62

var game: Node
var root: Node3D
var field: Node3D
var active: bool = false
var water: MeshInstance3D
var seabed: MeshInstance3D
var dust: CPUParticles3D
var boat: Node3D
var boat_yaw: float = 0.0
var boat_speed: float = 0.0
var aboard: bool = false
var bombs: Array = []
var bomb_cd: float = 0.0
var chests: Array = []
var serpent: Dictionary = {}
var last_safe: Vector3 = Vector3.ZERO
var safe_t: float = 0.0
var where: String = ""
var w_fog: float = 0.0
var w_dust: float = 0.0
var wraps: int = 0          # tests
var splashes: int = 0       # tests
var rocks_broken: int = 0   # tests
var bomb_mat: StandardMaterial3D
var survival: RefCounted       # IslesSurvival.gd: trees, wildlife, forage, cooking pot, bike
var foliage: RefCounted        # IslesFoliage.gd: canopy leaves, cliff vines, flower beds (scripts/cc/foliage)

func _init(g: Node) -> void:
	game = g

# ---------------------------------------------------------------- build

func build() -> void:
	active = true
	aboard = false
	bombs.clear()
	chests.clear()
	serpent.clear()
	game.win_text = "ISLES"
	game.boss_name = ""
	root = Node3D.new()
	root.name = "Isles"
	game.world.add_child(root)
	field = IsleBlocks.new()
	field.name = "IsleBlocks"
	root.add_child(field)
	var t0: int = Time.get_ticks_msec()
	field.build(ISLANDS)
	hint_rocks()
	var spawn: Vector3 = ground_point(Vector2(2, 16))
	var t1: int = Time.get_ticks_msec()
	# the ground round Lance first; the far islands are drawn over the next frames
	field.flush_near(spawn, 28.0)
	print("ISLES ground built in %d ms (shape %d ms, near mesh %d ms, %d chunks now, %d to come)" % [Time.get_ticks_msec() - t0, t1 - t0, Time.get_ticks_msec() - t1, field.chunks.size(), field.dirty.size()])
	game.sections = [{"goal": "Explore the isles", "spawn": spawn}]
	var zones: Array = []
	for isl: Dictionary in ISLANDS:
		var c: Vector2 = isl.c
		var r: float = isl.r
		for ox: float in [-WORLD, 0.0, WORLD]:
			for oz: float in [-WORLD, 0.0, WORLD]:
				zones.append(Rect2(c.x - r + ox, c.y - r + oz, r * 2, r * 2))
	game.map_zones = zones
	last_safe = spawn
	look()
	build_sea()
	build_boat()
	build_chests()
	build_dust()
	survival = SurvivalScript.new(self)
	survival.build(root)
	foliage = FoliageScript.new(self)
	foliage.build(root)

func look() -> void:
	var sm: ProceduralSkyMaterial = game.env_res.sky.sky_material
	sm.sky_top_color = Color("2f78d0")
	sm.sky_horizon_color = Color("9fcbe8")
	sm.ground_horizon_color = Color("9fcbe8")
	sm.ground_bottom_color = Color("1f5a78")
	game.env_res.ambient_light_color = Color("9fb6cc")
	game.env_res.ambient_light_energy = 0.5
	game.env_res.tonemap_exposure = 0.85
	game.env_res.fog_light_color = Color("a9cbe2")
	game.env_res.fog_density = 0.008
	game.sun.light_energy = 1.1
	game.sun.light_color = Color("fff1d6")
	game.sun.rotation_degrees = Vector3(-48, -36, 0)

func leave() -> void:
	if foliage != null:
		foliage.leave()
	active = false
	aboard = false
	if survival != null:
		survival.riding = false
	game.citadel_look()

## A standing point on the ground at (x, z).
func ground_point(p: Vector2) -> Vector3:
	return Vector3(p.x, field.top_at(p.x, p.y) + 0.4, p.y)

func build_sea() -> void:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(WORLD * 3.0, WORLD * 3.0)
	water = MeshInstance3D.new()
	water.mesh = pm
	water.name = "Sea"
	var wm: StandardMaterial3D = StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.32, 0.48, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.3
	wm.metallic = 0.0
	wm.metallic_specular = 0.6
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	water.position = Vector3(0, -0.02, 0)
	seabed = MeshInstance3D.new()
	var sb: PlaneMesh = PlaneMesh.new()
	sb.size = pm.size
	seabed.mesh = sb
	var bm: StandardMaterial3D = StandardMaterial3D.new()
	bm.albedo_color = Color("2b5a5e")
	bm.roughness = 1.0
	seabed.material_override = bm
	root.add_child(seabed)
	seabed.position = Vector3(0, field.SEA_FLOOR - 0.02, 0)

## A shaped hull (pointed bow, round stern, flared sides), mast and sail.
func build_boat() -> void:
	boat = Node3D.new()
	boat.name = "Boat"
	root.add_child(boat)
	var shell: Node3D = Node3D.new()
	shell.scale = Vector3.ONE * 1.4
	boat.add_child(shell)
	# a deck to stand on (Lance steers from the stern, Elyza sits amidships)
	var deck: StaticBody3D = StaticBody3D.new()
	deck.name = "Deck"
	var dcs: CollisionShape3D = CollisionShape3D.new()
	var dbox: BoxShape3D = BoxShape3D.new()
	dbox.size = Vector3(1.9, 0.2, 5.4)
	dcs.shape = dbox
	deck.add_child(dcs)
	deck.position = Vector3(0, DECK_Y - 0.1, 0.0)
	boat.add_child(deck)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood: Color = Color("8a5a34")
	var dark: Color = Color("5e3b22")
	var stations: int = 12
	var prev: Array = []
	for s in stations + 1:
		var t: float = float(s) / stations          # 0 stern -> 1 bow
		var z: float = lerpf(-2.1, 2.3, t)
		var w: float = 0.82 * pow(sin(PI * clampf(t * 0.92 + 0.06, 0.0, 1.0)), 0.55)
		if t > 0.75:
			w *= lerpf(1.0, 0.05, (t - 0.75) / 0.25)
		var rise: float = 0.18 * pow(t, 3.0) + 0.06 * pow(1.0 - t, 2.0)
		var ring: Array = [Vector3(-w, 0.45 + rise, z), Vector3(-w * 0.85, 0.05, z), Vector3(0, -0.32 + rise * 0.5, z), Vector3(w * 0.85, 0.05, z), Vector3(w, 0.45 + rise, z)]
		if not prev.is_empty():
			for k in 4:
				var col: Color = wood if k in [0, 3] else dark
				hull_quad(st, prev[k], prev[k + 1], ring[k + 1], ring[k], col)
			# deck strip
			hull_quad(st, prev[0], ring[0], ring[4], prev[4], Color("b08458"))
		prev = ring
	st.generate_normals()
	var hull: MeshInstance3D = MeshInstance3D.new()
	hull.mesh = st.commit()
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.roughness = 0.8
	hull.material_override = hm
	shell.add_child(hull)
	var mast: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.07
	cm.height = 3.4
	mast.mesh = cm
	mast.material_override = hm
	mast.position = Vector3(0, 2.1, 1.0)
	shell.add_child(mast)
	var ss: SurfaceTool = SurfaceTool.new()
	ss.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth: Color = Color("efe4c8")
	var band: Color = Color("3f8f5a")
	# a curved triangular sail in two strips
	var pts: Array = []
	for j in 6:
		var u: float = float(j) / 5.0
		pts.append([Vector3(0.06 + 0.25 * sin(u * PI), 0.75 + u * 2.6, 1.0), Vector3(0.06 + 0.35 * sin(u * PI) * (1.0 - u), 0.75 + u * 1.0, 1.0 - 1.6 * (1.0 - u))])
	for j in 5:
		var c: Color = band if j == 1 else cloth
		hull_quad(ss, pts[j][0], pts[j + 1][0], pts[j + 1][1], pts[j][1], c)
	ss.generate_normals()
	var sail: MeshInstance3D = MeshInstance3D.new()
	sail.mesh = ss.commit()
	sail.material_override = hm
	shell.add_child(sail)
	# moored off Home Isle's south beach
	var at: Vector2 = Vector2(4, 16)
	while field.top_at(at.x, at.y) > -0.9 and at.y < 60.0:
		at.y += 0.5
	at.y += 2.5
	boat.position = Vector3(at.x, 0.0, at.y)
	boat_yaw = 0.0
	boat.rotation.y = boat_yaw

func hull_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)

func build_chests() -> void:
	var mist: Vector2 = ISLANDS[3].c
	add_chest(ground_point(mist + Vector2(1.5, 0.5)), false, "MOON PEARL")
	var bp: Vector3 = Vector3(BURIED.x, field.top_at(BURIED.x, BURIED.y) - 1.6, BURIED.y)
	add_chest(bp, true, "SUN COMPASS")

## Four dark stones round the buried chest: the hint.
func hint_rocks() -> void:
	for a in 4:
		var ang: float = a * TAU / 4.0 + 0.4
		var p: Vector2 = BURIED + Vector2(cos(ang), sin(ang)) * 2.4
		field.add_rock(p, 0.45, 0.6, field.OBSIDIAN)
	field.top0 = field.top.duplicate()

func add_chest(pos: Vector3, buried: bool, prize: String) -> void:
	var node: Node3D = Node3D.new()
	node.name = "Chest"
	root.add_child(node)
	node.position = pos
	var body: MeshInstance3D = game.box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.66), "wood", false, node)
	body.position = Vector3(0, 0.3, 0)
	var lid_pivot: Node3D = Node3D.new()
	lid_pivot.position = Vector3(0, 0.6, -0.33)
	node.add_child(lid_pivot)
	var lid: MeshInstance3D = game.box(Vector3(0, 0.12, 0.33), Vector3(1.04, 0.24, 0.7), "gold", false, lid_pivot)
	lid.position = Vector3(0, 0.12, 0.33)
	chests.append({"node": node, "lid": lid_pivot, "buried": buried, "open": false, "prize": prize})

func build_dust() -> void:
	dust = CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 60 if game.phone else 160
	dust.lifetime = 2.2
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(14, 5, 14)
	dust.direction = Vector3(1, 0.05, 0.3)
	dust.spread = 12.0
	dust.initial_velocity_min = 7.0
	dust.initial_velocity_max = 13.0
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.6
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.5, 0.18)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.86, 0.72, 0.5, 0.45)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	dust.mesh = q
	dust.emitting = false
	root.add_child(dust)

# ---------------------------------------------------------------- cast

func spawn_cast() -> void:
	var h: Dictionary = game.HEROES[game.hero_key]
	var s0: Vector3 = game.sections[0].spawn
	game.hero = game.make_fighter("hero", h.model, 1.8, h.blade, 1.25, s0)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.hero.yaw = PI
	game.cam_yaw = PI
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, s0 + Vector3(2.0, 0.3, -1.2))
	game.ally.rig.sword.visible = false
	game.boss = null
	# two knights hold the top of Crag Isle
	var crag: Vector2 = ISLANDS[1].c
	for o: Vector2 in [Vector2(-2.5, 1.0), Vector2(2.0, -1.5)]:
		var p: Vector3 = ground_point(crag + o)
		var e: CharacterBody3D = game.make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, p)
		e.section = 0
		e.max_hp = 70
		e.hp = 70
		e.dmg = 6
		e.home = p
		game.enemies.append(e)
	survival.spawn_animals()

func start() -> void:
	game.say_once("isles_start", "tip", "The Isles: rocks break after a few sword hits. Darker rock is tougher.")
	game.say_once("isles_bomb", "tip", "BOMB blasts craters and tunnels. The boat is moored off the south beach.")
	game.say_once("isles_survival", "tip", "Chop trees, hunt, pick herbs. COOK at the pot by camp. BIKE summons the Stormrunner.")

# ---------------------------------------------------------------- per frame (hero)

## Called at the top of the hero's tick. Returns true when it handled the hero this frame (sailing).
func hero_tick(f: CharacterBody3D, dt: float, mv: Vector2) -> bool:
	bomb_cd = maxf(0.0, bomb_cd - dt)
	var playing: bool = game.mode == "play" and f.alive()
	var bomb: bool = game.hud.take("bomb") or Input.is_action_just_pressed("cc_bomb")
	var boat_btn: bool = game.hud.take("boat") or Input.is_action_just_pressed("cc_boat")
	var cook_btn: bool = game.hud.take("cook") or Input.is_action_just_pressed("cc_cook")
	var bike_btn: bool = game.hud.take("bike") or Input.is_action_just_pressed("cc_bike")
	if playing and cook_btn and survival.near_pot() and not survival.riding:
		survival.cook()
	if playing and bike_btn:
		survival.bike_button(f)
	if survival.riding:
		if playing and bomb:
			throw_bomb(f)
		survival.ride(f, mv, playing)
		return true
	if playing and bomb:
		throw_bomb(f)
	if playing and boat_btn:
		if aboard:
			land(f)
		elif boat_action() == "BOARD":
			board(f)
	if aboard:
		sail(f, dt, mv if playing else Vector2.ZERO)
		return true
	return false

func boat_action() -> String:
	var hero: CharacterBody3D = game.hero
	if hero == null or not hero.alive() or boat == null:
		return ""
	if aboard:
		return "LAND" if land_spot() != Vector3.INF else ""
	var d: Vector3 = hero.global_position - boat.position
	d.y = 0
	return "BOARD" if d.length() < 4.4 else ""

func board(f: CharacterBody3D) -> void:
	aboard = true
	boat_speed = 0.0
	f.velocity = Vector3.ZERO
	f.set_state("idle")
	game.hud.popup("ABOARD", Color("bfe9ff"))
	game.say_once("isles_sail", "tip", "Steer with the stick. LAND appears when a shore is close.")
	game.sound("step", -6)

func land(f: CharacterBody3D) -> void:
	var p: Vector3 = land_spot()
	if p == Vector3.INF:
		return
	aboard = false
	boat_speed = 0.0
	f.global_position = p
	f.velocity = Vector3.ZERO
	last_safe = p
	game.cam_pos = p
	if game.ally != null:
		game.ally.global_position = p + Vector3(0.8, 0.2, 0.8)
		game.ally.velocity = Vector3.ZERO
	game.hud.popup("LANDED", Color("bfe9ff"))

## The nearest dry standing point beside the boat, or Vector3.INF.
func land_spot() -> Vector3:
	var best: Vector3 = Vector3.INF
	var bd: float = 99.0
	for ring: float in [2.2, 3.0, 3.8, 4.6]:
		for a in 16:
			var ang: float = a * TAU / 16.0
			var p: Vector2 = Vector2(boat.position.x, boat.position.z) + Vector2(cos(ang), sin(ang)) * ring
			var ty: float = field.top_at(p.x, p.y)
			if ty < 0.2 or ty > 2.6:
				continue
			# room to stand: no rock right above
			if field.top_at(p.x + 0.5, p.y) > ty + 1.0 and field.top_at(p.x - 0.5, p.y) > ty + 1.0:
				continue
			if ring < bd:
				bd = ring
				best = Vector3(p.x, ty + 0.4, p.y)
		if best != Vector3.INF:
			return best
	return best

func sail(f: CharacterBody3D, dt: float, mv: Vector2) -> void:
	var dir: Vector3 = game.cam_right() * mv.x - game.cam_forward() * mv.y
	dir.y = 0
	var want: float = 0.0
	if dir.length() > 0.2:
		var target: float = atan2(dir.x, dir.z)
		boat_yaw = rotate_toward(boat_yaw, target, 1.8 * dt)
		want = BOAT_SPEED * clampf(dir.length(), 0.0, 1.0) * clampf(cos(angle_difference(boat_yaw, target)), 0.15, 1.0)
	boat_speed = move_toward(boat_speed, want, (5.0 if want > boat_speed else 7.0) * dt)
	var fwd: Vector3 = Vector3(sin(boat_yaw), 0, cos(boat_yaw))
	var nxt: Vector3 = boat.position + fwd * boat_speed * dt
	var bow: Vector3 = nxt + fwd * 3.0 * signf(boat_speed if absf(boat_speed) > 0.01 else 1.0)
	if field.top_at(bow.x, bow.z) > -0.7:
		boat_speed = 0.0     # run aground: stop at the shore
	else:
		boat.position = nxt
	var t: float = Time.get_ticks_msec() * 0.001
	boat.position.y = sin(t * 1.7) * 0.06
	boat.rotation = Vector3(0, boat_yaw, 0)
	(boat.get_child(0) as Node3D).rotation = Vector3(sin(t * 1.3) * 0.03, 0, sin(t * 1.1) * 0.04 - boat_speed * 0.004)
	f.global_position = boat.position + Vector3(0, DECK_Y + 0.02, 0) - fwd * 1.9
	f.velocity = Vector3(0, -0.5, 0)
	f.yaw = boat_yaw + PI     # Fighter.forward() is -z at yaw 0
	if f.state not in ["idle", "hurt", "dead"]:
		f.set_state("idle")

## Elyza sits in the stern while sailing.
func seat_ally(a: CharacterBody3D) -> void:
	var fwd: Vector3 = Vector3(sin(boat_yaw), 0, cos(boat_yaw))
	var side: Vector3 = Vector3(fwd.z, 0, -fwd.x)
	a.global_position = boat.position + Vector3(0, DECK_Y + 0.02, 0) - fwd * 0.2 + side * 0.35
	a.velocity = Vector3(0, -0.5, 0)
	a.yaw = boat_yaw + PI

# ---------------------------------------------------------------- sword and bombs

## A sword swing hits the rock in front of Lance at body height (never the floor under him).
func sword_hit(f: CharacterBody3D, reach: float, hit_enemy: bool) -> void:
	if survival.sword_hit(f, reach):
		return
	var p: Vector3 = f.global_position + f.forward() * minf(reach, 1.4) * 0.8 + Vector3.UP * 1.0
	var r: Dictionary = field.blast(p, 0.6, SWORD_POWER)
	if int(r.broken) > 0:
		rocks_broken += int(r.broken)
		game.fx.sparks(p, Color("d9d2c0"), 14, 6.0, -f.forward())
		game.sound("chip", -8)
		game.shake = maxf(game.shake, 0.25)
	elif int(r.chipped) > 0:
		game.fx.sparks(p, Color("ffe7a8"), 8, 5.0, -f.forward())
		if not hit_enemy:
			game.sound("knock", -10)

func throw_bomb(f: CharacterBody3D) -> void:
	if bomb_cd > 0.0 or bombs.size() >= 3:
		return
	bomb_cd = 0.7
	if bomb_mat == null:
		bomb_mat = StandardMaterial3D.new()
		bomb_mat.albedo_color = Color("1f2a44")
		bomb_mat.roughness = 0.35
		bomb_mat.metallic = 0.3
	var node: Node3D = Node3D.new()
	node.name = "Bomb"
	root.add_child(node)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.46
	mi.mesh = sm
	mi.material_override = bomb_mat
	node.add_child(mi)
	var fuse: MeshInstance3D = MeshInstance3D.new()
	var fm: SphereMesh = SphereMesh.new()
	fm.radius = 0.07
	fm.height = 0.14
	fuse.mesh = fm
	var em: StandardMaterial3D = StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color("ffb347")
	fuse.material_override = em
	fuse.position = Vector3(0, 0.27, 0)
	node.add_child(fuse)
	var fwd: Vector3 = f.forward()
	var start: Vector3 = f.global_position + fwd * 0.7 + Vector3.UP * 1.4
	var vel: Vector3 = fwd * 7.0 + Vector3.UP * 4.2
	if aboard:
		vel += Vector3(sin(boat_yaw), 0, cos(boat_yaw)) * boat_speed
	node.position = start
	bombs.append({"node": node, "vel": vel, "t": BOMB_FUSE, "fuse": fuse})
	game.sound("step", -4)

func tick_bombs(dt: float) -> void:
	for j in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[j]
		var nd: Node3D = b.node
		b.t = float(b.t) - dt
		var v: Vector3 = b.vel
		v.y -= 18.0 * dt
		var p: Vector3 = nd.position + v * dt
		var g: float = field.ground_for(p.x, p.y, p.z)
		if p.y - 0.24 < g and not field.is_solid(p.x, p.y + 0.3, p.z):
			p.y = g + 0.24
			v = Vector3(v.x * 0.55, absf(v.y) * 0.25, v.z * 0.55)
		elif field.is_solid(p.x, p.y, p.z):
			# hit a wall: stop and drop
			p = nd.position
			v = Vector3(0, minf(v.y, 0.0), 0)
		if p.y < 0.0 and field.top_at(p.x, p.z) < -0.2:
			p.y = -0.05 + sin(Time.get_ticks_msec() * 0.006) * 0.03    # floats
			v = v * 0.9
			v.y = 0.0
		nd.position = p
		b.vel = v
		(b.fuse as Node3D).visible = fmod(float(b.t) * (6.0 if float(b.t) > 0.7 else 16.0), 1.0) > 0.4
		if float(b.t) <= 0.0:
			explode(p)
			nd.queue_free()
			bombs.remove_at(j)

func explode(p: Vector3) -> void:
	var r: Dictionary = field.blast(p, BOMB_R, BOMB_POWER)
	if foliage != null:
		foliage.mgr.burn_sphere(p, BOMB_R + 0.6)   # a bomb's fire burns the foliage round it
	game.fx.sparks(p, Color("ffb347"), 40, 13.0)
	game.fx.sparks(p, Color("d8c7a4"), 24, 8.0)
	game.sound("explosion", -2)
	game.shake = maxf(game.shake, 0.9)
	if not game.phone:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color("ffb347")
		l.light_energy = 4.0
		l.omni_range = 9.0
		root.add_child(l)
		l.position = p + Vector3.UP * 0.6
		var tw: Tween = l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.35)
		tw.tween_callback(l.queue_free)
	for e: CharacterBody3D in game.enemies:
		if e.alive() and e.global_position.distance_to(p) < 3.2:
			game.wake(e)
			e.damage(35.0, p, 0.6)
	var hero: CharacterBody3D = game.hero
	if hero.alive() and hero.global_position.distance_to(p) < 2.4 and not aboard:
		hero.damage(10.0, p, 0.4)
		game.hud.popup("TOO CLOSE!", Color("ff8a8a"))
	if not serpent.is_empty() and int(serpent.hp) > 0:
		var head: Node3D = serpent.parts[0]
		if head.global_position.distance_to(p) < 3.4 and head.global_position.y > -1.2:
			serpent.hp = int(serpent.hp) - 1
			game.hud.popup("SERPENT HIT", Color("ffd27a"))
			serpent.lunge = -2.5
			if int(serpent.hp) <= 0:
				game.hud.popup("SERPENT DRIVEN OFF", Color("7dffcf"))
	if int(r.broken) > 0:
		rocks_broken += int(r.broken)

# ---------------------------------------------------------------- per frame (world)

func progress() -> void:
	var dt: float = game.get_process_delta_time()
	var hero: CharacterBody3D = game.hero
	if hero == null:
		return
	wrap_world()
	tick_bombs(dt)
	survival.progress(dt)
	water_check(hero, dt)
	weather(dt)
	tick_serpent(dt)
	tick_chests()
	var wp: Vector3 = hero.global_position
	water.position.x = snappedf(wp.x, 8.0)
	water.position.z = snappedf(wp.z, 8.0)
	seabed.position.x = water.position.x
	seabed.position.z = water.position.z
	var nm: String = island_name(Vector2(wp.x, wp.z))
	if nm != where:
		where = nm
		if nm != "" and nm != "OPEN SEA":
			game.hud.popup(nm, Color("f4e3b0"))
			if nm == "DUNE ISLE":
				game.say_once("isles_dune", "tip", "Something is buried where the four dark stones stand. Bombs dig.")
			elif nm == "MIST ISLE":
				game.say_once("isles_mist", "tip", "Mist Isle. Something big moves in the fog out at sea.")
	if aboard and game.ally != null:
		seat_ally(game.ally)

func island_name(p: Vector2) -> String:
	for isl: Dictionary in ISLANDS:
		if p.distance_to(isl.c) < float(isl.r) * 1.05:
			return isl.name
	return "OPEN SEA"

## Pac-Man wrap: leave one edge, come back on the opposite side.
func wrap_world() -> void:
	var hero: CharacterBody3D = game.hero
	var p: Vector3 = hero.global_position
	var shift: Vector3 = Vector3.ZERO
	if p.x > HALF:
		shift.x = -WORLD
	elif p.x < -HALF:
		shift.x = WORLD
	if p.z > HALF:
		shift.z = -WORLD
	elif p.z < -HALF:
		shift.z = WORLD
	if shift == Vector3.ZERO:
		return
	wraps += 1
	hero.global_position += shift
	game.cam_pos += shift
	if game.camera != null:
		game.camera.global_position += shift
	if aboard:
		boat.position += shift
	survival.shift(shift)
	if game.ally != null:
		game.ally.global_position += shift
	for b: Dictionary in bombs:
		(b.node as Node3D).position += shift
	if not serpent.is_empty():
		serpent.centre = (serpent.centre as Vector3) + shift

## Walking into deep water: splash and back to the last dry spot (old Zelda style).
func water_check(hero: CharacterBody3D, dt: float) -> void:
	if aboard or not hero.alive():
		return
	var p: Vector3 = hero.global_position
	safe_t -= dt
	if hero.is_on_floor() and field.top_at(p.x, p.z) > 0.3 and safe_t <= 0.0:
		last_safe = p + Vector3.UP * 0.2
		safe_t = 0.4
	if p.y < -0.7 and field.top_at(p.x, p.z) < -0.4:
		splashes += 1
		game.fx.sparks(Vector3(p.x, 0.1, p.z), Color("bfe9ff"), 26, 8.0)
		game.sound("hurt", -10)
		game.hud.popup("SPLASH", Color("bfe9ff"))
		hero.hp = maxf(1.0, hero.hp - 5.0)
		hero.global_position = last_safe
		hero.velocity = Vector3.ZERO
		game.cam_pos = last_safe
	var a: CharacterBody3D = game.ally
	if a != null and a.global_position.y < -0.7 and field.top_at(a.global_position.x, a.global_position.z) < -0.4:
		a.global_position = last_safe + Vector3(0.8, 0.2, 0.8)
		a.velocity = Vector3.ZERO

func wrapped_dist(a: Vector2, b: Vector2) -> float:
	var d: Vector2 = a - b
	d.x = wrapf(d.x + HALF, 0.0, WORLD) - HALF
	d.y = wrapf(d.y + HALF, 0.0, WORLD) - HALF
	return d.length()

## Fog and dust by zone, blended by distance.
func weather(dt: float) -> void:
	var p: Vector2 = Vector2(game.hero.global_position.x, game.hero.global_position.z)
	var f: float = 0.0
	var d: float = 0.0
	for z: Array in ZONES:
		var w: float = smoothstep(float(z[1]), float(z[1]) * 0.5, wrapped_dist(p, z[0]))
		if z[2] == "fog":
			f = maxf(f, w)
		else:
			d = maxf(d, w)
	w_fog = move_toward(w_fog, f, dt * 0.8)
	w_dust = move_toward(w_dust, d, dt * 0.8)
	var e: Environment = game.env_res
	e.fog_density = 0.008 + w_fog * 0.075 + w_dust * 0.05
	var col: Color = Color("a9cbe2").lerp(Color("97a6b0"), w_fog).lerp(Color("c49a62"), w_dust)
	e.fog_light_color = col
	e.fog_sky_affect = clampf(w_fog + w_dust, 0.0, 1.0) * 0.85
	game.sun.light_energy = 1.1 - w_fog * 0.5 - w_dust * 0.35
	dust.emitting = w_dust > 0.2
	dust.global_position = game.hero.global_position + Vector3(-6, 1.5, -2)

# ---------------------------------------------------------------- the serpent in the fog

func tick_serpent(dt: float) -> void:
	if serpent.is_empty():
		if aboard and w_fog > 0.5:
			spawn_serpent()
		return
	if int(serpent.hp) <= 0:
		# dives and is gone for good
		serpent.dive = float(serpent.dive) + dt
		for k in serpent.parts.size():
			(serpent.parts[k] as Node3D).position.y -= dt * 3.0
		if float(serpent.dive) > 2.5:
			for part: Node3D in serpent.parts:
				part.queue_free()
			serpent.parts.clear()
			serpent.hp = -99
		return
	if int(serpent.hp) == -99:
		return
	var hero: CharacterBody3D = game.hero
	var centre: Vector3 = boat.position if aboard else hero.global_position
	serpent.t = float(serpent.t) + dt
	serpent.lunge = float(serpent.lunge) + dt
	var rad: float = 8.0
	var lunge: float = float(serpent.lunge)
	if lunge > 5.0:
		rad = lerpf(8.0, 1.2, clampf((lunge - 5.0) / 1.0, 0.0, 1.0))
	if lunge > 6.6:
		serpent.lunge = 0.0
	var away: bool = not aboard or w_fog < 0.3
	if away:
		rad = 18.0
	var t: float = float(serpent.t)
	var parts: Array = serpent.parts
	for k in parts.size():
		var a: float = t * 0.7 - k * 0.32
		var p: Vector3 = centre + Vector3(cos(a), 0, sin(a)) * (rad + k * 0.15)
		p.y = sin(t * 2.0 - k * 0.9) * 0.55 + (0.5 if k == 0 else 0.0) - (2.5 if away else 0.0)
		(parts[k] as Node3D).global_position = p
	var head: Node3D = parts[0]
	head.look_at(head.global_position + Vector3(-sin(t * 0.7), 0, cos(t * 0.7)), Vector3.UP)
	if aboard and not away and head.global_position.distance_to(boat.position) < 2.4 and float(serpent.hit_cd) <= 0.0:
		serpent.hit_cd = 2.5
		hero.damage(12.0, head.global_position, 0.3)
		game.hud.popup("SERPENT!", Color("ff8a8a"))
		game.shake = maxf(game.shake, 0.8)
		boat_speed *= 0.3
	serpent.hit_cd = float(serpent.hit_cd) - dt

func spawn_serpent() -> void:
	var parts: Array = []
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color("2d5e57")
	skin.roughness = 0.4
	skin.metallic = 0.2
	for k in 8:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		var r: float = 0.75 - k * 0.06 if k > 0 else 0.6
		sm.radius = r
		sm.height = r * 1.6
		mi.mesh = sm
		mi.material_override = skin
		if k == 0:
			mi.scale = Vector3(0.9, 0.8, 1.5)
			for s: float in [-0.28, 0.28]:
				var eye: MeshInstance3D = MeshInstance3D.new()
				var em: SphereMesh = SphereMesh.new()
				em.radius = 0.09
				em.height = 0.18
				eye.mesh = em
				var gm: StandardMaterial3D = StandardMaterial3D.new()
				gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				gm.albedo_color = Color("ffe066")
				eye.material_override = gm
				eye.position = Vector3(s, 0.2, -0.4)
				mi.add_child(eye)
		root.add_child(mi)
		parts.append(mi)
	serpent = {"parts": parts, "hp": 3, "t": 0.0, "lunge": 0.0, "hit_cd": 0.0, "dive": 0.0, "centre": Vector3.ZERO}
	game.hud.popup("SOMETHING IN THE FOG", Color("ffd27a"))
	game.say_once("isles_serpent", "tip", "A sea serpent! Throw BOMBS at its head when it surfaces.")

# ---------------------------------------------------------------- chests

func tick_chests() -> void:
	var hero: CharacterBody3D = game.hero
	for c: Dictionary in chests:
		var nd: Node3D = c.node
		if c.open:
			var lid: Node3D = c.lid
			lid.rotation.x = move_toward(lid.rotation.x, -1.9, game.get_process_delta_time() * 4.0)
			continue
		if c.buried:
			var g: float = field.ground_for(nd.position.x, nd.position.y + 1.2, nd.position.z)
			if field.top_at(nd.position.x, nd.position.z) <= nd.position.y + 0.9:
				c.buried = false
				nd.position.y = g
				game.hud.popup("SOMETHING SHINES IN THE SAND", Color("ffd27a"))
			continue
		var d: Vector3 = hero.global_position - nd.position
		if Vector2(d.x, d.z).length() < 1.6 and absf(d.y) < 1.8:
			c.open = true
			game.potions = mini(game.potions + 2, 5)
			hero.hp = hero.max_hp
			game.hud.popup("FOUND: " + str(c.prize), Color("ffe08a"))
			game.say("tip", "Treasure! Health refilled and +2 potions.")
			game.sound("win", -8)

func fall_line() -> float:
	return -30.0
