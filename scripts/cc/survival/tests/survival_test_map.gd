extends Node3D
## CC survival test map: one island with trees, wildlife, a cooking pot, a campfire, a bike
## pad and a sanctum circle where the bike can't be summoned.
## Run the checks:  godot --path . res://scenes/systems/cc_survival_test.tscn -- --cc-test --quit-after-test [--shots=/dir]

const IsleBlocks = preload("res://scripts/citadel/IsleBlocks.gd")
const TreeNode = preload("res://scripts/cc/survival/tree_node.gd")
const Wildlife = preload("res://scripts/cc/survival/wildlife_agent.gd")
const CookSite = preload("res://scripts/cc/survival/cook_site.gd")
const Bike = preload("res://scripts/cc/survival/bike.gd")
const Zone = preload("res://scripts/cc/survival/summon_zone.gd")

const ISLAND: Array = [{"name": "TEST ISLE", "c": Vector2(0, 0), "r": 30.0, "h": 2.4, "style": 1, "rocks": 0, "dark": 0.0}]
const BIKE_PAD: Vector2 = Vector2(-12, 10)
const SANCTUM: Vector2 = Vector2(14, 12)

var ground: Node3D
var trees: Array = []
var animals: Array = []
var pot: Node3D
var campfire: Node3D
var bike: CharacterBody3D
var sanctum: Node3D
var hunter: Node3D
var hunter_noise: float = 0.5
var camera: Camera3D

func _ready() -> void:
	build_env()
	ground = IsleBlocks.new()
	add_child(ground)
	ground.build(ISLAND)
	ground.flush()
	var oak: Resource = load("res://data/cc/trees/oak.tres")
	var pine: Resource = load("res://data/cc/trees/pine.tres")
	var spots: Array = [Vector2(-4, -8), Vector2(2, -12), Vector2(8, -6), Vector2(-10, -4), Vector2(12, -12)]
	for i in spots.size():
		var t: StaticBody3D = TreeNode.new()
		t.tree = oak if i % 2 == 0 else pine
		t.seed_value = 100 + i
		add_child(t)
		t.global_position = at(spots[i])
		trees.append(t)
	var herd: Array = [["mossback_doe", Vector2(-6, 14)], ["mossback_doe", Vector2(4, 18)], ["bristle_boar", Vector2(16, -2)], ["dune_hare", Vector2(-16, -12)]]
	for h: Array in herd:
		var a: CharacterBody3D = Wildlife.new()
		a.species = h[0]
		add_child(a)
		a.global_position = at(h[1]) + Vector3.UP * 0.3
		animals.append(a)
	pot = CookSite.new()
	pot.has_pot = true
	add_child(pot)
	pot.global_position = at(Vector2(0, 4))
	campfire = CookSite.new()
	campfire.has_pot = false
	add_child(campfire)
	campfire.global_position = at(Vector2(4, 6))
	build_pad()
	bike = Bike.new()
	add_child(bike)
	bike.global_position = at(BIKE_PAD) + Vector3.UP * 0.6
	sanctum = Zone.new()
	sanctum.tag = "sanctum"
	sanctum.radius = 5.0
	add_child(sanctum)
	sanctum.global_position = at(SANCTUM)
	build_sanctum_ring()
	hunter = make_hunter()
	add_child(hunter)
	hunter.global_position = at(Vector2(0, 0))
	for a: CharacterBody3D in animals:
		a.threat = hunter
		a.noise_fn = func() -> float: return hunter_noise
	if "--cc-test" in OS.get_cmdline_user_args():
		var t2: Node = load("res://scripts/cc/survival/tests/survival_tests.gd").new()
		t2.set("map", self)
		add_child(t2)

func at(p: Vector2) -> Vector3:
	return Vector3(p.x, ground.top_at(p.x, p.y), p.y)

func build_env() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2f78d0")
	sm.sky_horizon_color = Color("9fcbe8")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9fb6cc")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var sea: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	sea.mesh = pm
	var wm: StandardMaterial3D = StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.32, 0.48, 0.85)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = wm
	sea.position.y = -0.02
	add_child(sea)
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	camera.position = Vector3(0, 26, 38)
	camera.look_at(Vector3(0, 0, 2))

func build_pad() -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("8a8274")
	m.roughness = 0.9
	var pad: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.5
	cm.height = 0.5
	pad.mesh = cm
	pad.material_override = m
	add_child(pad)
	pad.global_position = at(BIKE_PAD) + Vector3.UP * 0.05

func build_sanctum_ring() -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("d8d2c2")
	m.emission_enabled = true
	m.emission = Color("7dffcf")
	m.emission_energy_multiplier = 0.3
	for i in 10:
		var a: float = i * TAU / 10.0
		var p: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.26
		cm.height = 1.6
		p.mesh = cm
		p.material_override = m
		add_child(p)
		var q: Vector2 = SANCTUM + Vector2(cos(a), sin(a)) * sanctum.radius
		p.global_position = at(q) + Vector3.UP * 0.8

func make_hunter() -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Hunter"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("3b5a8c")
	mi.material_override = m
	n.add_child(mi)
	return n
