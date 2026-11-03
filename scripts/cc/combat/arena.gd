extends Node3D
## CC combat arena. Round 1: CC_Lance vs one Briar Knight on patrol (sneak up on him or
## fight). Round 2: three Briar Knights and a Briar Archer.
## Open: /play/?arena (or the ARENA card on the title). Tests: -- --combat-test.

const PlayerScript = preload("res://scripts/cc/combat/cc_player.gd")
const EnemyScript = preload("res://scripts/cc/combat/cc_enemy.gd")
const Tactics = preload("res://scripts/cc/combat/group_tactics.gd")
const CameraScript = preload("res://scripts/cc/combat/camera_director.gd")
const HudScript = preload("res://scripts/cc/combat/combat_hud.gd")

var player: CharacterBody3D
var camera: Node3D   # camera_director.gd (owns the Camera3D)
var hud: Control
var tactics: Node
var enemies: Array = []
var round_no: int = 1
var state: String = "play"
var mats: Dictionary = {}
var autopilot: bool = false     # tests drive the player directly
const CLIFF: Vector3 = Vector3(-17, 0, 10)
const LEDGE: Vector3 = Vector3(14, 0, 16)
const TOWER: Vector3 = Vector3(17, 0, -10)

func _ready() -> void:
	setup_input()
	build_env()
	build_arena()
	tactics = Tactics.new()
	add_child(tactics)
	camera = CameraScript.new()
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.arena = self
	layer.add_child(hud)
	start_round(1)
	if "--move-test" in OS.get_cmdline_user_args():
		autopilot = true
		var mt: Node = load("res://scripts/cc/combat/tests/movement_tests.gd").new()
		mt.set("arena", self)
		add_child(mt)
	elif "--combat-test" in OS.get_cmdline_user_args():
		autopilot = true
		var t: Node = load("res://scripts/cc/combat/tests/combat_tests.gd").new()
		t.set("arena", self)
		add_child(t)

func setup_input() -> void:
	var keys: Dictionary = {"cca_left": [KEY_A, KEY_LEFT], "cca_right": [KEY_D, KEY_RIGHT], "cca_up": [KEY_W, KEY_UP], "cca_down": [KEY_S, KEY_DOWN],
		"cca_attack": [KEY_J], "cca_guard": [KEY_K], "cca_dodge": [KEY_L], "cca_jump": [KEY_SPACE], "cca_lock": [KEY_TAB], "cca_sprint": [KEY_SHIFT], "cca_crouch": [KEY_C], "cca_aim": [KEY_V], "cca_weapon": [KEY_Q], "cca_restart": [KEY_R]}
	for n: String in keys:
		if InputMap.has_action(n):
			continue
		InputMap.add_action(n)
		for code: int in keys[n]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(n, ev)

func mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	if mats.has(c):
		return mats[c]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	mats[c] = m
	return m

func build_env() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3a5f9e")
	sm.sky_horizon_color = Color("d9b98a")
	sm.ground_horizon_color = Color("8f7652")
	sm.ground_bottom_color = Color("5a4a36")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b0a8a0")
	e.ambient_light_energy = 0.4
	e.tonemap_exposure = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.006
	e.fog_light_color = Color("c9a97a")
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -40, 0)
	sun.light_color = Color("ffe6c0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

func climbable(b: StaticBody3D) -> void:
	b.add_to_group("cc_climbable")

func solid(pos: Vector3, size: Vector3, c: Color, round_top: bool = false) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	if round_top:
		var cy: CylinderShape3D = CylinderShape3D.new()
		cy.radius = size.x * 0.5
		cy.height = size.y
		cs.shape = cy
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = size.x * 0.42
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 12
		mi.mesh = cm
	else:
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	body.add_child(cs)
	mi.material_override = mat(c)
	body.add_child(mi)
	return body

## A round sand floor ringed by a low stone wall, four pillars to break line of sight.
func build_arena() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	add_child(floor_body)
	var fcs: CollisionShape3D = CollisionShape3D.new()
	var cy: CylinderShape3D = CylinderShape3D.new()
	cy.radius = 26.0
	cy.height = 1.0
	fcs.shape = cy
	fcs.position.y = -0.5
	floor_body.add_child(fcs)
	var fm: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 26.0
	cm.bottom_radius = 26.0
	cm.height = 1.0
	cm.radial_segments = 48
	fm.mesh = cm
	fm.material_override = mat(Color("8f7652"))
	fm.position.y = -0.5
	floor_body.add_child(fm)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 8.6
	tm.outer_radius = 9.0
	tm.rings = 48
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override = mat(Color("9c8463"))
	add_child(ring)
	for i in 28:
		var a: float = i * TAU / 28.0
		var p: Vector3 = Vector3(cos(a), 0, sin(a)) * 25.0
		var seg: float = 2.0 * 25.0 * sin(PI / 28.0) + 0.3
		var body: StaticBody3D = StaticBody3D.new()
		add_child(body)
		body.position = p + Vector3.UP * 0.9
		body.rotation.y = -a + PI * 0.5
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(seg, 1.8, 1.0)
		cs.shape = bs
		body.add_child(cs)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.material_override = mat(Color("8b8378"))
		body.add_child(mi)
	for p: Vector3 in [Vector3(-11, 0, -6), Vector3(11, 0, -6), Vector3(-7, 0, 11), Vector3(8, 0, 10)]:
		solid(p + Vector3.UP * 2.0, Vector3(1.8, 4.0, 1.8), Color("9a9188"), true)
	# traversal pieces: a climbable cliff, a waist-high ledge, a 12 m climbable tower
	climbable(solid(CLIFF + Vector3.UP * 3.0, Vector3(8.0, 6.0, 2.0), Color("7d7368")))
	solid(LEDGE + Vector3.UP * 0.5, Vector3(3.0, 1.0, 2.0), Color("a89a86"))
	climbable(solid(TOWER + Vector3.UP * 6.0, Vector3(3.0, 12.0, 3.0), Color("857b70")))

func clear_round() -> void:
	for e: Node in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("cc_arrow.gd"):
			c.queue_free()
	if player != null:
		player.queue_free()
		player = null
	for e2: Node in get_tree().get_nodes_in_group("cc_enemy"):
		e2.remove_from_group("cc_enemy")
	if player == null:
		for p2: Node in get_tree().get_nodes_in_group("cc_player"):
			p2.remove_from_group("cc_player")
	if tactics != null:
		tactics.reset()
	TimeDilation.release()

func start_round(n: int) -> void:
	clear_round()
	round_no = n
	state = "play"
	StaminaPool.refill()
	InventoryService.weapons.clear()
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3(0, 0.1, 14)
	player.yaw = 0.0
	camera.set_player(player)
	camera.cam_yaw = 0.0
	var knight: Resource = load("res://data/cc/combat/briar_knight.tres")
	var archer: Resource = load("res://data/cc/combat/briar_archer.tres")
	if n == 1:
		var e: CharacterBody3D = spawn(knight, Vector3(0, 0.1, -4))
		e.route = [Vector3(-6, 0, -4), Vector3(6, 0, -4)]
		hud.say("ROUND 1: one Briar Knight. Sneak up, or fight.")
	else:
		for p: Vector3 in [Vector3(-5, 0.1, -6), Vector3(0, 0.1, -8), Vector3(5, 0.1, -6)]:
			var e2: CharacterBody3D = spawn(knight, p)
			e2.route = [p + Vector3(-3, 0, 0), p + Vector3(3, 0, 0)]
		spawn(archer, Vector3(0, 0.1, -16))
		hud.say("ROUND 2: three Knights and an Archer.")

func spawn(profile: Resource, at: Vector3) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.profile = profile
	add_child(e)
	e.global_position = at
	e.yaw = 0.0
	enemies.append(e)
	return e

func _physics_process(_dt: float) -> void:
	if player == null:
		return
	if not autopilot:
		hud.feed(player)
	if Input.is_action_just_pressed("cca_restart"):
		start_round(round_no)
		return
	if state == "play":
		if not player.alive():
			state = "lost"
		else:
			var left: int = 0
			for e: Node in enemies:
				if is_instance_valid(e) and e.alive():
					left += 1
			if left == 0:
				state = "won"

func title_text() -> String:
	var left: int = 0
	for e: Node in enemies:
		if is_instance_valid(e) and e.alive():
			left += 1
	return "ARENA  ·  ROUND %d  ·  FOES LEFT %d" % [round_no, left]

func menu_title() -> String:
	return "VICTORY" if state == "won" else "DEFEATED"

func menu() -> Array:
	var out: Array = []
	var w: float = get_viewport().get_visible_rect().size.x / hud.scale_ui
	var x: float = w * 0.5 - 150.0
	if state == "won" and round_no == 1:
		out.append({"rect": Rect2(x, 260, 300, 70), "label": "ROUND 2", "act": "next"})
	out.append({"rect": Rect2(x, 345, 300, 70), "label": "AGAIN", "act": "again"})
	out.append({"rect": Rect2(x, 430, 300, 70), "label": "BACK TO TITLE", "act": "title"})
	return out

func menu_tap(p: Vector2) -> void:
	for mb: Dictionary in menu():
		if (mb.rect as Rect2).has_point(p):
			match mb.act:
				"next":
					start_round(2)
				"again":
					start_round(round_no)
				"title":
					TimeDilation.release()
					get_tree().change_scene_to_file("res://scenes/citadel.tscn")
