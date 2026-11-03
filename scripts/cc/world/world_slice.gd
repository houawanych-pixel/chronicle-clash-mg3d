extends Node3D
## CC world slice: chemistry + weather + powers + durability in one small place.
##   north: a 10 m climbable cliff · east: a grass field with a brazier on its upwind edge
##   south-west: a pond (Frost Pillar, shock in water) · west: Frostpeak (snow, cold)
##   crates: a metal one (lightning, blasts) and a wooden one · a spare weapon to pick up
##   debug: RAIN / STORM / OMEN / CLEAR buttons top-left.
## Open: /play/?world (or the WORLD card). Tests: -- --world-test

const PlayerScript = preload("res://scripts/cc/combat/cc_player.gd")
const EnemyScript = preload("res://scripts/cc/combat/cc_enemy.gd")
const Tactics = preload("res://scripts/cc/combat/group_tactics.gd")
const CameraScript = preload("res://scripts/cc/combat/camera_director.gd")
const HudScript = preload("res://scripts/cc/world/world_hud.gd")
const GrassField = preload("res://scripts/cc/world/grass_field.gd")
const Water = preload("res://scripts/cc/world/water_volume.gd")
const Brazier = preload("res://scripts/cc/world/brazier.gd")
const Climate = preload("res://scripts/cc/world/climate_region.gd")

const CLIFF: Vector3 = Vector3(0, 0, -30)
const FIELD: Vector3 = Vector3(20, 0, 0)
const FIELD_SIZE: Vector2 = Vector2(24, 24)
const BRAZIER: Vector3 = Vector3(6.5, 0, 0)
const POND: Vector3 = Vector3(-18, -0.3, 10)     # water surface; the basin is 4 m deep
const POND_SIZE: Vector3 = Vector3(12, 4.0, 12)
const DIVE_TOWER: Vector3 = Vector3(-26.5, 0, 10)  # 14 m climbable cliff on the pond's west bank
const SLOPES: Array = [["grass", Vector3(14, 0, 24)], ["snow", Vector3(-28, 0, -26)], ["rock", Vector3(26, 0, -22)]]
const SNOW: Vector3 = Vector3(-28, 0, -22)

var player: CharacterBody3D
var camera: Node3D
var hud: Control
var tactics: Node
var field: Node3D
var pond: Node3D
var brazier: StaticBody3D
var metal_crate: RigidBody3D
var wood_crate: RigidBody3D
var knight: CharacterBody3D
var pickups: Array = []      # [{node, id, life}]
var state: String = "play"
var autopilot: bool = false
var swap_offer: String = ""
var swap_pick: Dictionary = {}
var warn_t: float = 0.0
var cold_t: float = 0.0
var cold_hits: int = 0
var mats: Dictionary = {}
var rain_fx: CPUParticles3D

func _ready() -> void:
	setup_input()
	build_env()
	build_world()
	tactics = Tactics.new()
	add_child(tactics)
	camera = CameraScript.new()
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.arena = self
	layer.add_child(hud)
	ChemistryService.lightning_warn.connect(func(_at: Vector3, t: Node3D) -> void:
		if t == player:
			warn_t = float(ChemistryService.tuning.lightning_warn_s))
	start()
	if "--travel-test" in OS.get_cmdline_user_args():
		autopilot = true
		var tt2: Node = load("res://scripts/cc/world/tests/travel_tests.gd").new()
		tt2.set("world", self)
		add_child(tt2)
	elif "--world-test" in OS.get_cmdline_user_args():
		autopilot = true
		var t: Node = load("res://scripts/cc/world/tests/world_tests.gd").new()
		t.set("world", self)
		add_child(t)

func setup_input() -> void:
	var keys: Dictionary = {"cca_left": [KEY_A, KEY_LEFT], "cca_right": [KEY_D, KEY_RIGHT], "cca_up": [KEY_W, KEY_UP], "cca_down": [KEY_S, KEY_DOWN],
		"cca_attack": [KEY_J], "cca_guard": [KEY_K], "cca_dodge": [KEY_L], "cca_jump": [KEY_SPACE], "cca_lock": [KEY_TAB], "cca_sprint": [KEY_SHIFT],
		"cca_crouch": [KEY_C], "cca_aim": [KEY_V], "cca_weapon": [KEY_Q], "cca_restart": [KEY_R], "ccw_use": [KEY_E], "ccw_ability": [KEY_F], "ccw_throw": [KEY_T]}
	for n: String in keys:
		if InputMap.has_action(n):
			continue
		InputMap.add_action(n)
		for code: int in keys[n]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(n, ev)

func mat(c: Color) -> StandardMaterial3D:
	if not mats.has(c):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		mats[c] = m
	return mats[c]

func build_env() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3a6fb5")
	sm.sky_horizon_color = Color("c7d9e6")
	sm.ground_horizon_color = Color("8a9a7a")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a8b4bf")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.72
	e.fog_enabled = true
	e.fog_density = 0.004
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	rain_fx = CPUParticles3D.new()
	rain_fx.amount = 400
	rain_fx.lifetime = 0.8
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(14, 1, 14)
	rain_fx.direction = Vector3(0.1, -1, 0)
	rain_fx.spread = 4.0
	rain_fx.initial_velocity_min = 18.0
	rain_fx.initial_velocity_max = 22.0
	rain_fx.gravity = Vector3.ZERO
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.02, 0.5)
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.8, 0.9, 1.0, 0.45)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = rm
	rain_fx.mesh = q
	rain_fx.emitting = false
	add_child(rain_fx)

func box(pos: Vector3, size: Vector3, c: Color) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	add_child(b)
	b.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c)
	b.add_child(mi)
	return b

func ground(pos: Vector3, size: Vector3, c: Color) -> StaticBody3D:
	var b: StaticBody3D = box(pos, size, c)
	b.set_meta("surface", "grass")
	return b

## A 20 degree slope (10 m long) of snow, grass or rock, rising toward -z, for shield surfing.
func slope(surface: String, at: Vector3) -> void:
	var c: Color = {"snow": Color("e8eef2"), "grass": Color("5d7a3e"), "rock": Color("7a7268")}[surface]
	var ang: float = deg_to_rad(20.0)
	var length: float = 10.0
	var b: StaticBody3D = box(Vector3.ZERO, Vector3(6, 0.4, length), c)
	b.set_meta("surface", surface)
	b.position = at + Vector3(0, sin(ang) * length * 0.5 - 0.1, 0)
	b.rotation.x = ang
	b.add_to_group("cc_slope")

func crate(pos: Vector3, metal: bool) -> RigidBody3D:
	var b: RigidBody3D = RigidBody3D.new()
	b.mass = 10.0
	b.add_to_group("cc_prop")
	if metal:
		b.add_to_group("cc_metal")
	b.set_meta("chem", "metal" if metal else "wood")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1, 1, 1)
	cs.shape = bs
	b.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("8a96a3") if metal else Color("8a5a34")
	m.metallic = 0.8 if metal else 0.0
	m.roughness = 0.35 if metal else 0.9
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	b.global_position = pos
	return b

func build_world() -> void:
	# ground in four slabs round the pond basin
	var px0: float = POND.x - POND_SIZE.x * 0.5
	var px1: float = POND.x + POND_SIZE.x * 0.5
	var pz0: float = POND.z - POND_SIZE.z * 0.5
	var pz1: float = POND.z + POND_SIZE.z * 0.5
	var g: Color = Color("55633f")
	ground(Vector3((-45 + px0) * 0.5, -0.5, 0), Vector3(px0 + 45, 1, 90), g)
	ground(Vector3((px1 + 45) * 0.5, -0.5, 0), Vector3(45 - px1, 1, 90), g)
	ground(Vector3(POND.x, -0.5, (-45 + pz0) * 0.5), Vector3(POND_SIZE.x, 1, pz0 + 45), g)
	ground(Vector3(POND.x, -0.5, (pz1 + 45) * 0.5), Vector3(POND_SIZE.x, 1, 45 - pz1), g)
	ground(Vector3(POND.x, -4.8, POND.z), Vector3(POND_SIZE.x, 1, POND_SIZE.z), Color("3d4a4a"))
	var dive: StaticBody3D = box(DIVE_TOWER + Vector3(0, 7, 0), Vector3(3, 14, 3), Color("7d7368"))
	dive.add_to_group("cc_climbable")
	dive.set_meta("surface", "rock")
	for sl: Array in SLOPES:
		slope(str(sl[0]), sl[1])
	var cliff: StaticBody3D = box(CLIFF + Vector3(0, 5, 0), Vector3(14, 10, 3), Color("7d7368"))
	cliff.add_to_group("cc_climbable")
	box(SNOW + Vector3(0, 0.02, 0), Vector3(20, 0.04, 20), Color("e8eef2"))
	var snow: Node3D = Climate.new()
	snow.profile = load("res://data/cc/weather/frostpeak.tres")
	snow.size = Vector2(20, 20)
	add_child(snow)
	snow.global_position = SNOW
	field = GrassField.new()
	field.size = FIELD_SIZE
	add_child(field)
	field.global_position = FIELD
	brazier = Brazier.new()
	add_child(brazier)
	brazier.global_position = BRAZIER
	pond = Water.new()
	pond.size = POND_SIZE
	add_child(pond)
	pond.global_position = POND

func start() -> void:
	for c: Node in get_children():
		if c is RigidBody3D or c.is_in_group("cc_pillar") or c.is_in_group("cc_orb"):
			c.queue_free()
	if player != null:
		player.queue_free()
	if knight != null and is_instance_valid(knight):
		knight.queue_free()
	for e: Node in get_tree().get_nodes_in_group("cc_enemy"):
		e.remove_from_group("cc_enemy")
	for p: Node in get_tree().get_nodes_in_group("cc_player"):
		p.remove_from_group("cc_player")
	for pk: Dictionary in pickups:
		if is_instance_valid(pk.node):
			(pk.node as Node).queue_free()
	pickups.clear()
	ChemistryService.reset()
	AbilityService.reset()
	WeatherService.locked = true
	WeatherService.apply("clear", Vector3(3, 0, 0))
	WorldClock.force_omen = false
	InventoryService.weapons.clear()
	InventoryService.stacks.erase("arrow")
	InventoryService.stacks.erase("fire_arrow")
	InventoryService.add("arrow", 30)
	InventoryService.add("fire_arrow", 10)
	StaminaPool.refill()
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 6)
	camera.set_player(player)
	camera.cam_yaw = 0.0
	WeatherService.probe = player
	metal_crate = crate(Vector3(4, 0.6, -4), true)
	wood_crate = crate(Vector3(-4, 0.6, -4), false)
	knight = EnemyScript.new()
	knight.profile = load("res://data/cc/combat/briar_knight.tres")
	add_child(knight)
	knight.global_position = POND + Vector3(2, 0.1, 2)
	knight.dummy = true
	knight.route = []
	add_pickup("warden_greatblade", 100.0, Vector3(-3, 0.3, 9))
	hud.say("Light the grass. Then try STORM.")

func add_pickup(id: String, life: float, at: Vector3) -> void:
	var n: Node3D = Node3D.new()
	n.name = "Pickup"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.12, 1.4, 0.04)
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color("ffd27a")
	m.emission_enabled = true
	m.emission = Color("ffb347")
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.rotation.z = 0.6
	n.add_child(mi)
	add_child(n)
	n.global_position = at
	pickups.append({"node": n, "id": id, "life": life})

# ---------------------------------------------------------------- per frame

func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not autopilot:
		hud.feed(player)
		if Input.is_action_just_pressed("ccw_use"):
			hud_button("use")
		if Input.is_action_just_pressed("ccw_ability"):
			hud_button("ability")
		if Input.is_action_just_pressed("ccw_throw"):
			hud_button("throw")
		if Input.is_action_just_pressed("cca_restart"):
			start()
			return
	# glider over fire rises
	if player.state == "glide":
		player.updraft = ChemistryService.updraft_at(player.global_position)
	vitals(dt)
	warn_t = maxf(0.0, warn_t - dt)
	rain_fx.emitting = WeatherService.is_precipitating and not WeatherService.is_snowing
	rain_fx.global_position = player.global_position + Vector3(0, 9, 0)
	pickups_tick()

## Cold: below 0 °C without cold resist you lose health every second.
func vitals(dt: float) -> void:
	if WeatherService.temperature() < 0.0 and not player.cold_resist and player.alive():
		cold_t += dt
		if cold_t >= 1.0:
			cold_t = 0.0
			cold_hits += 1
			player.apply_damage(3.0, player.global_position, 0.0)
			hud.say("FREEZING")
	else:
		cold_t = 0.0

func pickups_tick() -> void:
	var near: Dictionary = {}
	for pk: Dictionary in pickups:
		var n: Node3D = pk.node
		if not is_instance_valid(n):
			continue
		n.rotation.y += 0.03
		var d: Vector3 = n.global_position - player.global_position
		if Vector2(d.x, d.z).length() < 1.3:
			near = pk
	if near.is_empty():
		swap_offer = ""
		swap_pick = {}
		return
	if swap_offer != "":
		return
	if player.try_pickup(str(near.id), float(near.life)):
		(near.node as Node).queue_free()
		pickups.erase(near)
		hud.say("GOT " + str(load("res://data/cc/combat/weapons/%s.tres" % near.id).display_name).to_upper())
	else:
		swap_offer = str(near.id)
		swap_pick = near

func do_swap() -> void:
	if swap_pick.is_empty():
		return
	var old: Array = player.swap_for(str(swap_pick.id), float(swap_pick.life))
	var at: Vector3 = (swap_pick.node as Node3D).global_position
	(swap_pick.node as Node).queue_free()
	pickups.erase(swap_pick)
	swap_offer = ""
	swap_pick = {}
	if not old.is_empty():
		add_pickup(str(old[0]), float(old[1]), at + Vector3(1.6, 0, 0))

func hud_button(id: String) -> void:
	match id:
		"use":
			var r: String = AbilityService.use(player)
			if r == "no water":
				hud.say("NO WATER AHEAD")
		"ability":
			AbilityService.cycle()
			hud.say(AbilityService.display_name(AbilityService.active).to_upper())
		"throw":
			player.press("throw")

func debug(what: String) -> void:
	match what:
		"rain":
			WeatherService.apply("rain")
		"thunder":
			WeatherService.apply("thunder")
		"clear":
			WeatherService.apply("clear")
		"omen":
			WorldClock.force_omen = not WorldClock.force_omen
			hud.say("OMEN NIGHT" if WorldClock.force_omen else "OMEN OFF")

# arena-style API used by the HUD
func title_text() -> String:
	return "WORLD SLICE"

func menu() -> Array:
	return []

func menu_tap(_p: Vector2) -> void:
	pass

func menu_title() -> String:
	return ""
