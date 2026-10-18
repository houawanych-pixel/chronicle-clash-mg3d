extends RefCounted
## Village stage: a 3x3 grid of small blocks, one loaded at a time.
## Each block has its own villagers who never leave it. Walking off an open
## edge saves this block and loads the neighbour. Phase 1 builds two blocks
## (Village Square and Mill Lane); the rest of the grid is closed by fences.
const VillagerScript = preload("res://scripts/citadel/Villager.gd")
const WorkSpotScript = preload("res://scripts/citadel/WorkSpot.gd")
const SaveScript = preload("res://scripts/citadel/VillageSave.gd")
const ChatScript = preload("res://scripts/citadel/VillageChat.gd")
const KIT: String = "res://assets/village/village_kit.glb"

const HALF: float = 20.0           # blocks are 40 x 40 m
const KIT_SCALE: float = 58.0      # kit buildings are ~0.15 units wide
const WORK_CYCLE: float = 45.0     # game minutes per log / ore / fish / sack
const START_CLOCK: float = 7.0 * 60.0 + 30.0
const GRID: Dictionary = {"square": Vector2i(1, 1), "mill": Vector2i(2, 1)}
const JOB_SPOTS: Dictionary = {
	"woodcutter": ["tree"], "miner": ["rock"], "fisher": ["fish"],
	"merchant": ["stall"], "farmer": ["field"],
}
const VILLAGER_MODELS: Array = [
	"res://assets/characters/lance_lite.glb",
	"res://assets/characters/eliza_lite.glb",
	"res://assets/characters/blonde_lance_lite.glb",
]

## Block layouts. Buildings: [kit id, x, z, facing degrees (0 = door faces +Z)].
const BLOCKS: Dictionary = {
	"square": {
		"title": "Village Square",
		"buildings": [
			["b12", -12.0, -13.0, 0.0, "home_bram"], ["b01", 0.0, -14.0, 0.0, "shop"], ["b21", 12.0, -13.0, 0.0, "inn"],
			["b22", -14.5, 1.0, 90.0, "home_finn"], ["b15", 14.5, 11.0, -90.0, "chapel"], ["b23", 1.0, 15.0, 180.0, "home_tam"],
		],
		"pond": [-11.0, 12.5, 9.0, 7.0, "north"],
		"rocks": [[11.0, 14.5, 1.5], [14.5, 4.5, 1.1]],
		"work_trees": [[-17.0, -5.0], [-4.0, -18.5]],
		"trees": [[-18, 8], [-18, -18], [18, -18], [6, 18.5], [18, 18], [-8, 18.5], [-18.5, -12]],
		"benches": [[-5.0, 5.5, 180.0], [5.0, 5.5, 180.0]],
		"stall": [0.0, -7.5],
		"drops": {"woodcutter": [-8.0, -7.0], "miner": [8.0, -7.0], "fisher": [3.0, -7.5]},
		"plaza": [0.0, 0.0, 6.5],
		"well": true,
		"exits": {"east": "mill"},
		"spawn": Vector3(0.0, 0.2, 7.0),
		"villagers": [
			{"id": "sq_bram", "name": "Bram", "job": "woodcutter", "home": "home_bram", "model": 0, "tint": Color(0.5, 0.25, 0.1), "persona": "Big, slow-spoken and kind. Proud of his axe work and the timber he cuts for every roof in the square. Teases Finn about never catching anything. Worries the knights will want his wood for war."},
			{"id": "sq_mara", "name": "Mara", "job": "miner", "home": "inn", "model": 1, "tint": Color(0.35, 0.3, 0.25), "persona": "Tough, blunt and funny. Lives at the inn and swings a pick all day. Knows every rumour from the miners' table. Secretly saving coin to buy her own house.", "female": true},
			{"id": "sq_finn", "name": "Finn", "job": "fisher", "home": "home_finn", "model": 2, "tint": Color(0.1, 0.25, 0.45), "persona": "Young, cheerful and a little boastful about the big fish he almost caught. Talks fast. Loves the quiet of the dock at dawn. Sweet on Lia but too shy to say so."},
			{"id": "sq_ivo", "name": "Ivo", "job": "merchant", "home": "shop", "model": 0, "tint": Color(0.45, 0.1, 0.35), "persona": "A sharp merchant who sells bread, rope and lamp oil. Always tries to make a sale, haggles for fun, and trades gossip from travellers on the road."},
			{"id": "sq_tam", "name": "Old Tam", "job": "elder", "home": "home_tam", "model": 2, "tint": Color(0.4, 0.4, 0.4), "speed": 1.1, "height": 1.7, "persona": "The village elder. Old, wise and patient, speaks slowly and remembers when the sky citadel was built. Gives advice whether you ask or not. Fond of everyone, especially the young.", "pitch": 0.75, "rate": 0.85},
			{"id": "sq_lia", "name": "Lia", "job": "wanderer", "home": "chapel", "model": 1, "tint": Color(0.1, 0.4, 0.2), "persona": "A friendly wanderer who visits everyone and carries news around the village. Curious about the knight's adventures, hums songs, and dreams of seeing the citadel.", "female": true},
		],
	},
	"mill": {
		"title": "Mill Lane",
		"buildings": [
			["b13", 9.0, -11.0, 0.0, "windmill"], ["b17", -12.0, -12.0, 0.0, "home_ada"], ["b14", -14.5, 10.0, 90.0, "home_rolf"],
			["b06", 14.5, 11.0, -90.0, "home_kit"], ["b20", 2.0, 16.0, 180.0, "home_nell"],
		],
		"pond": [-1.5, -13.5, 6.0, 5.0, "south"],
		"rocks": [[16.5, 0.5, 1.3]],
		"work_trees": [[16.5, -5.0], [-6.0, 17.5]],
		"trees": [[-18, -3], [-18, 18], [18, 18], [18, -18], [-6, -19]],
		"fields": [[-1.0, 6.5, 10.0, 5.0]],
		"benches": [[5.0, -4.5, 180.0]],
		"drops": {"farmer": [5.5, -6.5], "miller": [4.0, -6.0], "woodcutter": [10.0, 3.5], "fisher": [1.5, -9.0]},
		"plaza": [3.0, 0.0, 5.0],
		"exits": {"west": "square"},
		"spawn": Vector3(-16.0, 0.2, 0.0),
		"villagers": [
			{"id": "ml_ada", "name": "Ada", "job": "farmer", "home": "home_ada", "model": 1, "tint": Color(0.45, 0.35, 0.1), "persona": "A hard-working farmer, warm and practical. Married to Rolf. Reads the weather in her bones. Feeds the whole lane at harvest and scolds anyone who steps in her furrows.", "female": true},
			{"id": "ml_rolf", "name": "Rolf", "job": "farmer", "home": "home_rolf", "model": 0, "tint": Color(0.3, 0.2, 0.1), "persona": "A quiet farmer of few words, married to Ada. Dry sense of humour. Proud of his wheat and grumbles about crows and tax collectors."},
			{"id": "ml_wes", "name": "Wes", "job": "miller", "home": "windmill", "model": 2, "tint": Color(0.5, 0.5, 0.45), "persona": "The miller. Dusty with flour, loud because the mill is loud, and fond of a good joke. Grinds grain for both parts of the village and knows everyone's business by what they buy."},
			{"id": "ml_kit", "name": "Kit", "job": "woodcutter", "home": "home_kit", "model": 0, "tint": Color(0.2, 0.35, 0.15), "persona": "A young woodcutter, eager to prove himself to Bram in the square. Asks the knight about swords and dreams of joining the guard one day."},
			{"id": "ml_nell", "name": "Nell", "job": "fisher", "home": "home_nell", "model": 1, "tint": Color(0.15, 0.3, 0.5), "persona": "A calm fisher who talks to the river like an old friend. Gentle, observant, notices small things others miss. Believes strange lights have been seen in the forest at night.", "female": true},
			{"id": "ml_pip", "name": "Pip", "job": "wanderer", "home": "home_ada", "model": 2, "tint": Color(0.5, 0.15, 0.15), "height": 1.55, "speed": 1.9, "persona": "A small, quick, mischievous lad who runs everywhere and asks a hundred questions. Lives with Ada. Thinks the knight is the most exciting thing that has ever happened.", "pitch": 1.45, "rate": 1.12},
		],
	},
}
const SECTION_TEMPLATE: Dictionary = {"goal": "Explore the village", "spawn": Vector3(0, 0.2, 7.0)}

var game: Node
var active: bool = false
var block: String = "square"
var clock: float = START_CLOCK     # game minutes since day 1, 00:00
var speed: float = 1.0             # test hook: speeds up game time
var villagers: Array = []
var spots: Dictionary = {}
var doors: Dictionary = {}
var region: NavigationRegion3D
var kit_meshes: Dictionary = {}
var save: Dictionary = {}
var autosave_t: float = 0.0
var switching: float = 0.0
var deliveries: Dictionary = {}

var chat: RefCounted

func _init(g: Node) -> void:
	game = g
	chat = ChatScript.new(g, self)

func minutes_per_second() -> float:
	## One real hour is one village day (1440 game minutes / 3600 s).
	return 0.4 * speed

func hour() -> float:
	return fmod(clock, 1440.0) / 60.0

func day() -> int:
	return int(clock / 1440.0) + 1

func clock_text() -> String:
	var m: int = int(fmod(clock, 1440.0))
	return "DAY %d  %02d:%02d" % [day(), m / 60, m % 60]

## The daily routine. Elders sit instead of working; wanderers socialise.
func activity_for(v: Node) -> String:
	var h: float = hour()
	if h < 6.0 or h >= 21.5:
		return "sleep"
	if h < 7.0:
		return "wake"
	if h >= 12.0 and h < 13.0:
		return "eat"
	if h >= 18.0:
		return "social"
	if v.job == "wanderer":
		return "social"
	return "work"

# ---------------------------------------------------------------- stage setup

func configure_stage() -> void:
	var sec: Dictionary = SECTION_TEMPLATE.duplicate()
	sec.goal = "%s  ·  explore" % BLOCKS[block].title
	sec.spawn = BLOCKS[block].spawn
	game.sections = [sec]
	game.map_zones = [Rect2(-HALF, -HALF, HALF * 2, HALF * 2)]
	game.win_text = "VILLAGE"
	game.boss_name = ""

func look() -> void:
	game.env_res.fog_density = 0.006
	game.sun.rotation_degrees = Vector3(-50, 40, 0)
	apply_daylight()

## 1 in full day, 0 at night, ramping over dawn (5-7) and dusk (19-21).
func daylight() -> float:
	var h: float = hour()
	return clampf(minf((h - 5.0) / 2.0, (21.0 - h) / 2.0), 0.0, 1.0)

## Tints sky, fog and lights from the clock. Cheap: a few colour sets.
func apply_daylight() -> void:
	var d: float = daylight()
	var dusk: float = 1.0 - absf(d - 0.5) * 2.0   # warm tint mid-ramp
	var e: Environment = game.env_res
	var sm: ProceduralSkyMaterial = e.sky.sky_material
	sm.sky_top_color = Color("0b1530").lerp(Color("3d74c9"), d)
	var hz: Color = Color("1e2a48").lerp(Color("d9e6f2"), d).lerp(Color("f0a070"), dusk * 0.45)
	sm.sky_horizon_color = hz
	sm.ground_horizon_color = hz
	sm.ground_bottom_color = Color("1a2016").lerp(Color("4d5a3a"), d)
	e.fog_light_color = Color("26324e").lerp(Color("d6e2ea"), d)
	e.ambient_light_color = Color("5a6a9a").lerp(Color("b7c4c8"), d)
	e.ambient_light_energy = lerpf(0.42, 0.6, d)
	game.sun.light_color = Color("9fb4ff").lerp(Color("fff0d2"), d).lerp(Color("ffb070"), dusk * 0.5)
	game.sun.light_energy = lerpf(0.22, 1.15, d)

func reset_light() -> void:
	game.env_res.ambient_light_energy = 0.6
	game.sun.light_energy = 1.15

func mat(id: String, color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key: String = "v_" + id
	if game.mats.has(key):
		return game.mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if id == "water":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 0.8
		m.roughness = 0.1
	game.mats[key] = m
	return m

func load_kit() -> void:
	if not kit_meshes.is_empty():
		return
	var inst: Node = (load(KIT) as PackedScene).instantiate()
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		kit_meshes[str(mi.name)] = mi.mesh
	inst.free()

func shape_box(parent: Node3D, pos: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	body.rotation.y = rot_y
	parent.add_child(body)

func visual_box(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

func add_spot(id: String, kind: String, at: Vector3, look_at: Vector3, tool: String = "none") -> RefCounted:
	var s: RefCounted = WorkSpotScript.new(id, kind, at, look_at, tool)
	spots[id] = s
	return s

func build() -> void:
	load_kit()
	look()
	spots.clear()
	doors.clear()
	var def: Dictionary = BLOCKS[block]
	var w: Node3D = game.world
	# Ground.
	var ground: MeshInstance3D = game.box(Vector3(0, -0.5, 0), Vector3(HALF * 2 + 30, 1, HALF * 2 + 30), "marble", true)
	ground.material_override = mat("grass", Color("6f9a46"))
	var plaza: Array = def.plaza
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = plaza[2]
	cm.bottom_radius = plaza[2]
	cm.height = 0.04
	cm.radial_segments = 24
	disc.mesh = cm
	disc.material_override = mat("cobble", Color("a59a86"))
	disc.position = Vector3(plaza[0], 0.02, plaza[1])
	w.add_child(disc)
	# Roads to the open exits.
	for dir: String in def.exits:
		var road: Vector3 = Vector3(HALF * 0.5 + plaza[0] * 0.5, 0.015, plaza[1]) if dir == "east" else Vector3(-HALF * 0.5 + plaza[0] * 0.5, 0.015, plaza[1])
		visual_box(w, road, Vector3(HALF + absf(plaza[0]), 0.03, 4.0), mat("dirt", Color("9c8256")))
	# Buildings with box colliders and a door spot in front.
	for b: Array in def.buildings:
		place_building(b[0], Vector3(b[1], 0, b[2]), deg_to_rad(b[3]), b[4])
	if def.has("well") and def.well:
		visual_box(w, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.6), mat("stone", Color("8d8a83")))
		visual_box(w, Vector3(0, 1.9, 0), Vector3(1.9, 0.15, 1.9), mat("wood", Color("6b4b2e")))
		shape_box(w, Vector3(0, 0.5, 0), Vector3(1.7, 1.0, 1.7))
	build_pond(def.pond)
	for i in def.rocks.size():
		var r: Array = def.rocks[i]
		ore_rock(Vector3(r[0], 0, r[1]), r[2], "rock_%d" % i, Vector3(plaza[0], 0, plaza[1]))
	for i in def.work_trees.size():
		var t: Array = def.work_trees[i]
		var tp: Vector3 = Vector3(t[0], 0, t[1])
		game.forest.tree(tp, 7.5, true)
		var toward: Vector3 = (Vector3(plaza[0], 0, plaza[1]) - tp).normalized()
		add_spot("tree_%d" % i, "tree", tp + toward * 1.25, tp + Vector3.UP, "axe")
	for t: Array in def.trees:
		game.forest.tree(Vector3(t[0], 0, t[1]), randf_range(6.5, 9.0), true)
	game.forest.flush_trees()
	if def.has("fields"):
		for i in def.fields.size():
			var f: Array = def.fields[i]
			visual_box(w, Vector3(f[0], 0.03, f[1]), Vector3(f[2], 0.06, f[3]), mat("soil", Color("6b4e2e")))
			for row in 5:
				visual_box(w, Vector3(f[0], 0.25, f[1] - f[3] * 0.4 + row * f[3] * 0.2), Vector3(f[2] * 0.9, 0.4, 0.35), mat("wheat", Color("d9b84a")))
			add_spot("field_%d_a" % i, "field", Vector3(f[0] - f[2] * 0.25, 0, f[1] + f[3] * 0.5 + 0.6), Vector3(f[0] - f[2] * 0.25, 0, f[1]), "hoe")
			add_spot("field_%d_b" % i, "field", Vector3(f[0] + f[2] * 0.25, 0, f[1] + f[3] * 0.5 + 0.6), Vector3(f[0] + f[2] * 0.25, 0, f[1]), "hoe")
	for i in def.benches.size():
		var bn: Array = def.benches[i]
		var bp: Vector3 = Vector3(bn[0], 0, bn[1])
		var rot: float = deg_to_rad(bn[2])
		visual_box(w, bp + Vector3(0, 0.42, 0), Vector3(1.8, 0.1, 0.55), mat("wood", Color("6b4b2e")), rot)
		visual_box(w, bp + Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 0.4), mat("wood", Color("6b4b2e")), rot)
		var facing: Vector3 = Vector3(0, 0, 1).rotated(Vector3.UP, rot)
		add_spot("seat_%d_a" % i, "seat", bp + facing.cross(Vector3.UP) * 0.45, bp + facing * 3.0 + facing.cross(Vector3.UP) * 0.45)
		add_spot("seat_%d_b" % i, "seat", bp - facing.cross(Vector3.UP) * 0.45, bp + facing * 3.0 - facing.cross(Vector3.UP) * 0.45)
	if def.has("stall"):
		var st: Vector3 = Vector3(def.stall[0], 0, def.stall[1])
		visual_box(w, st + Vector3(0, 0.5, 1.0), Vector3(2.4, 1.0, 0.8), mat("wood", Color("6b4b2e")))
		visual_box(w, st + Vector3(0, 2.3, 0.9), Vector3(2.8, 0.1, 1.6), mat("awning", Color("b8403a")))
		shape_box(w, st + Vector3(0, 0.5, 1.0), Vector3(2.4, 1.0, 0.8))
		add_spot("stall", "stall", st, st + Vector3(0, 0, 4))
	for job: String in def.drops:
		var dp: Array = def.drops[job]
		var at: Vector3 = Vector3(dp[0], 0, dp[1])
		var colors: Dictionary = {"woodcutter": Color("7a5532"), "miner": Color("6d6f73"), "fisher": Color("8fb1c4"), "farmer": Color("d9b84a"), "miller": Color("e8e0cc")}
		visual_box(w, at + Vector3(0.9, 0.3, 0), Vector3(1.0, 0.6, 1.0), mat("drop_" + job, colors.get(job, Color.GRAY)))
		add_spot("drop_" + job, "drop", at, at + Vector3(1, 0, 0))
	build_edges(def.exits)
	bake_nav()

func place_building(kit_id: String, pos: Vector3, rot: float, door_id: String) -> void:
	var mesh: Mesh = kit_meshes.get(kit_id)
	if mesh == null:
		push_warning("village kit missing " + kit_id)
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * KIT_SCALE
	mi.position = pos
	mi.rotation.y = rot
	if game.phone:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.world.add_child(mi)
	var aabb: AABB = mesh.get_aabb()
	var size: Vector3 = aabb.size * KIT_SCALE
	var center: Vector3 = (aabb.position + aabb.size * 0.5) * KIT_SCALE
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(size.x * 0.86, size.y, size.z * 0.86)
	cs.shape = sh
	body.add_child(cs)
	body.position = pos + Vector3(center.x, size.y * 0.5, center.z).rotated(Vector3.UP, rot)
	body.rotation.y = rot
	game.world.add_child(body)
	game.add_wall(Rect2(pos.x - size.x * 0.43, pos.z - size.z * 0.43, size.x * 0.86, size.z * 0.86), size.y)
	var front: Vector3 = Vector3(0, 0, size.z * 0.43 + 0.9).rotated(Vector3.UP, rot)
	var door: RefCounted = add_spot("door_" + door_id, "door", pos + front, pos)
	doors[door_id] = door
	if door_id == "windmill":
		add_spot("mill_door", "mill_door", pos + front, pos)

func build_pond(p: Array) -> void:
	## Water with a dock. Colliders keep walkers out except along the dock.
	var c: Vector3 = Vector3(p[0], 0, p[1])
	var sx: float = p[2]
	var sz: float = p[3]
	var side: String = p[4]
	var water: MeshInstance3D = visual_box(game.world, c + Vector3(0, 0.03, 0), Vector3(sx, 0.04, sz), mat("water", Color(0.25, 0.5, 0.65, 0.85)))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual_box(game.world, c + Vector3(0, 0.01, 0), Vector3(sx + 1.0, 0.02, sz + 1.0), mat("bank", Color("8c7b55")))
	var sgn: float = -1.0 if side == "north" else 1.0      # edge the dock starts from
	var dock_len: float = sz * 0.55
	var edge_z: float = c.z + sgn * sz * 0.5
	var dock_mid: Vector3 = Vector3(c.x, 0.08, edge_z - sgn * dock_len * 0.5)
	visual_box(game.world, dock_mid, Vector3(1.4, 0.12, dock_len + 0.6), mat("wood", Color("6b4b2e")))
	var lx: float = (sx - 1.6) * 0.5
	shape_box(game.world, Vector3(c.x - 0.8 - lx * 0.5, 0.5, c.z), Vector3(lx, 1.0, sz))
	shape_box(game.world, Vector3(c.x + 0.8 + lx * 0.5, 0.5, c.z), Vector3(lx, 1.0, sz))
	var far_len: float = sz - dock_len
	shape_box(game.world, Vector3(c.x, 0.5, edge_z - sgn * (dock_len + far_len * 0.5)), Vector3(1.6, 1.0, far_len))
	var fish_at: Vector3 = Vector3(c.x, 0, edge_z - sgn * (dock_len - 0.6))
	add_spot("fish", "fish", fish_at, fish_at - Vector3(0, 0, sgn * 4.0), "rod")

func ore_rock(pos: Vector3, r: float, id: String, toward: Vector3) -> void:
	game.forest.boulder(pos, r)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r * 0.25
	sm.height = r * 0.35
	mi.mesh = sm
	mi.material_override = mat("ore", Color("c27a3a"), 0.4)
	mi.position = pos + Vector3(r * 0.3, r * 1.0, r * 0.45)
	game.world.add_child(mi)
	var dir: Vector3 = (toward - pos)
	dir.y = 0
	dir = dir.normalized()
	add_spot(id, "rock", pos + dir * (r * 0.8 + 1.0), pos + Vector3.UP * 0.5, "pick")

func build_edges(exits: Dictionary) -> void:
	## Fences round the block; gaps only where a neighbour block exists.
	var fence: StandardMaterial3D = mat("fence", Color("7a5a38"))
	var sides: Dictionary = {
		"north": [Vector3(0, 0, -HALF), Vector3(1, 0, 0)], "south": [Vector3(0, 0, HALF), Vector3(1, 0, 0)],
		"west": [Vector3(-HALF, 0, 0), Vector3(0, 0, 1)], "east": [Vector3(HALF, 0, 0), Vector3(0, 0, 1)],
	}
	for side: String in sides:
		var c: Vector3 = sides[side][0]
		var along: Vector3 = sides[side][1]
		var gap: bool = exits.has(side)
		var pieces: Array = [[-HALF, HALF]] if not gap else [[-HALF, -2.5], [2.5, HALF]]
		for pc: Array in pieces:
			var mid: float = (pc[0] + pc[1]) * 0.5
			var length: float = pc[1] - pc[0]
			var at: Vector3 = c + along * mid
			var size: Vector3 = Vector3(length, 1.0, 0.25) if along.x != 0.0 else Vector3(0.25, 1.0, length)
			visual_box(game.world, at + Vector3(0, 0.55, 0), size, fence)
			visual_box(game.world, at + Vector3(0, 0.95, 0), size * Vector3(1, 0.15, 1), fence)
			shape_box(game.world, at + Vector3(0, 1.0, 0), Vector3(size.x, 2.0, size.z))
		if gap:
			# Hero-only gate: villagers are kept in by an invisible bar they can't path through.
			var bar: Vector3 = c + Vector3(0, 0.5, 0)
			var post: StandardMaterial3D = mat("post", Color("5a4028"))
			visual_box(game.world, c + along * 2.7 + Vector3(0, 1.4, 0), Vector3(0.35, 2.8, 0.35), post)
			visual_box(game.world, c - along * 2.7 + Vector3(0, 1.4, 0), Vector3(0.35, 2.8, 0.35), post)
			var keep: StaticBody3D = StaticBody3D.new()
			keep.collision_layer = 8
			var cs: CollisionShape3D = CollisionShape3D.new()
			var sh: BoxShape3D = BoxShape3D.new()
			sh.size = Vector3(5.0, 2.0, 0.3) if along.x != 0.0 else Vector3(0.3, 2.0, 5.0)
			cs.shape = sh
			keep.add_child(cs)
			keep.position = bar - (c.normalized() * 1.5)
			game.world.add_child(keep)

func bake_nav() -> void:
	## Walkable area from every static collider in the block (buildings,
	## rocks, trees, pond, fences, the villager-only gate bars).
	region = NavigationRegion3D.new()
	var nm: NavigationMesh = NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 8
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	game.world.add_child(region)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, game.world)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	region.navigation_mesh = nm
	# Make the new mesh queryable straight away (villagers plan on spawn).
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), nm)
	NavigationServer3D.map_force_update(game.get_world_3d().navigation_map)

# ---------------------------------------------------------------- spots

func claim_nearest(v: Node, kinds: Array) -> RefCounted:
	var best: RefCounted = null
	var best_d: float = INF
	for s: RefCounted in spots.values():
		if s.kind in kinds and s.is_free_for(v):
			var d: float = s.pos.distance_to(v.global_position)
			if d < best_d:
				best_d = d
				best = s
	if best and best.claim(v):
		return best
	return null

func spot_of_kind(kind: String) -> RefCounted:
	for s: RefCounted in spots.values():
		if s.kind == kind:
			return s
	return null

func drop_for(job: String) -> RefCounted:
	return spots.get("drop_" + job)

func on_delivery(v: Node) -> void:
	deliveries[v.job] = int(deliveries.get(v.job, 0)) + 1

func random_point(center: Vector3, radius: float) -> Vector3:
	var map: RID = game.get_world_3d().navigation_map
	var c: Vector3 = center
	if center == Vector3.ZERO:
		var pl: Array = BLOCKS[block].plaza
		c = Vector3(pl[0], 0, pl[1])
	# A random reachable point: walk a path from the centre toward a random
	# spot and stop where the path ends (never inside a building or pond).
	for i in 8:
		var a: float = randf() * TAU
		var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, radius)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, c, p, true)
		if path.size() > 0:
			var q: Vector3 = path[path.size() - 1]
			if q.distance_to(p) < 1.0 and absf(q.x) < HALF - 1.5 and absf(q.z) < HALF - 1.5:
				return Vector3(q.x, 0.0, q.z)
	return c

# ---------------------------------------------------------------- cast, save, flow

func spawn_cast() -> void:
	active = true
	var hero_def: Dictionary = game.HEROES[game.hero_key]
	var at: Vector3 = BLOCKS[block].spawn
	game.hero = game.make_fighter("hero", hero_def.model, 1.8, hero_def.blade, 1.25, at)
	game.hero.max_hp = 100
	game.hero.hp = 100
	game.ally = game.make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, at + Vector3(1.6, 0, 1.6))
	game.ally.rig.sword.visible = false
	spawn_villagers()

func spawn_villagers() -> void:
	clear_villagers()
	var def: Dictionary = BLOCKS[block]
	var saved: Dictionary = save.get("blocks", {}).get(block, {})
	var saved_v: Dictionary = saved.get("villagers", {})
	var same_time: bool = saved.has("saved_clock") and absf(float(saved.saved_clock) - clock) < 5.0
	for d: Dictionary in def.villagers:
		var v: CharacterBody3D = CharacterBody3D.new()
		v.set_script(VillagerScript)
		game.add_child(v)
		var vd: Dictionary = d.duplicate()
		vd.model = VILLAGER_MODELS[int(d.model) % VILLAGER_MODELS.size()]
		v.setup(game, self, vd)
		v.home_door = doors.get(d.home, spots.values()[0])
		v.global_position = v.home_door.pos
		if game.phone:
			game.add_blob(v, v.height)
		villagers.append(v)
	# Restore exactly if nothing has moved on; otherwise jump to the routine.
	for v: Node in villagers:
		if saved_v.has(v.vid) and same_time:
			v.restore(saved_v[v.vid])
		else:
			if saved_v.has(v.vid):
				var sd: Dictionary = saved_v[v.vid]
				v.work_count = int(sd.get("work_count", 0))
			v.place_for_schedule()

func clear_villagers() -> void:
	chat.stop()
	for v: Node in villagers:
		if is_instance_valid(v):
			v.release_spot()
			v.queue_free()
	villagers.clear()

func block_state() -> Dictionary:
	var vs: Dictionary = {}
	for v: Node in villagers:
		vs[v.vid] = v.to_dict()
	return {"saved_clock": snappedf(clock, 0.1), "villagers": vs}

func save_now() -> void:
	if not active:
		return
	if not save.has("blocks"):
		save["blocks"] = {}
	save.blocks[block] = block_state()
	save["clock"] = snappedf(clock, 0.1)
	save["block"] = block
	SaveScript.save_data(save)

func load_save() -> void:
	save = SaveScript.load_data()
	clock = float(save.get("clock", START_CLOCK))
	var b: String = str(save.get("block", "square"))
	block = b if BLOCKS.has(b) else "square"

func enter() -> void:
	## Called when the village stage is chosen.
	load_save()
	configure_stage()

func start() -> void:
	game.say("ally", "%s. It's quiet here... people just living their lives." % BLOCKS[block].title)
	game.say_once("village_tip", "tip", "Walk up to villagers to talk. Leave by the road to reach the next part of the village.")

func leave() -> void:
	## Leaving the village stage: save and freeze everything.
	save_now()
	clear_villagers()
	reset_light()
	active = false

func progress(dt: float) -> void:
	clock += dt * minutes_per_second()
	apply_daylight()
	chat.tick(dt)
	autosave_t += dt
	if autosave_t > 20.0:
		autosave_t = 0.0
		save_now()
	if switching > 0.0:
		switching -= dt
		return
	var p: Vector3 = game.hero.global_position
	var exits: Dictionary = BLOCKS[block].exits
	if p.x > HALF - 0.6 and exits.has("east"):
		switch_block(exits.east, Vector3(-HALF + 2.5, 0.2, clampf(p.z, -2.0, 2.0)))
	elif p.x < -HALF + 0.6 and exits.has("west"):
		switch_block(exits.west, Vector3(HALF - 2.5, 0.2, clampf(p.z, -2.0, 2.0)))
	elif p.z > HALF - 0.6 and exits.has("south"):
		switch_block(exits.south, Vector3(clampf(p.x, -2.0, 2.0), 0.2, -HALF + 2.5))
	elif p.z < -HALF + 0.6 and exits.has("north"):
		switch_block(exits.north, Vector3(clampf(p.x, -2.0, 2.0), 0.2, HALF - 2.5))

func switch_block(to: String, hero_at: Vector3) -> void:
	save_now()
	clear_villagers()
	block = to
	game.build_stage()
	game.hero.global_position = hero_at
	game.hero.velocity = Vector3.ZERO
	game.ally.global_position = hero_at + Vector3(0.0, 0, 1.6)
	game.cam_pos = hero_at
	spawn_villagers()
	save_now()
	switching = 0.6
	game.hud.fade = 1.0
	game.hud.popup(BLOCKS[block].title.to_upper(), Color("ffe08a"))
