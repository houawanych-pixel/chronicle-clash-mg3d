extends Node3D
## Chronicle Clash — Sky Citadel. Sword action stage built from the owner's
## concept screens: courtyard, broken sky bridge, plaza, Dark Knight throne.
## Touch: left stick moves; JUMP, ATTACK, BLOCK. Keys: WASD, Space, J, K.
const FighterScript = preload("res://scripts/citadel/Fighter.gd")
const HUDScript = preload("res://scripts/citadel/CitadelHUD.gd")
const AutoTestScript = preload("res://scripts/citadel/AutoTest.gd")
const PatrolScript = preload("res://scripts/citadel/Patrol.gd")
const ForestScript = preload("res://scripts/citadel/Forest.gd")
const RuinScript = preload("res://scripts/citadel/Ruin.gd")
const FxScript = preload("res://scripts/citadel/Fx.gd")
const VillageScript = preload("res://scripts/citadel/Village.gd")
const CITADEL_ZONES: Array = [Rect2(-13, -38, 26, 42), Rect2(-3.5, -92, 7, 54), Rect2(-14, -128, 28, 36), Rect2(-12, -172, 24, 44)]
const Spatial = preload("res://scripts/StealthMath.gd")

const HEROES: Dictionary = {
	"blonde_lance": {"name": "BLONDE LANCE", "model": "res://assets/characters/blonde_lance.glb", "blade": Color("8fe9ff")},
	"lance": {"name": "LANCE", "model": "res://assets/characters/lance.glb", "blade": Color("b48cff")},
}
const SECTIONS: Array = [
	{"goal": "Defeat the courtyard guards", "spawn": Vector3(0, 0.2, 1.0)},
	{"goal": "Cross the broken sky bridge", "spawn": Vector3(0, 0.2, -40.0)},
	{"goal": "Clear the plaza", "spawn": Vector3(0, 0.2, -95.0)},
	{"goal": "Defeat the Dark Knight", "spawn": Vector3(0, 0.2, -131.0)},
]

var stage: String = "citadel"
var sections: Array = SECTIONS
var map_zones: Array = CITADEL_ZONES
var forest: RefCounted
## The Sky Citadel (the floating ruin). "classic" is the original boxed layout,
## kept for the combat and stealth regression tests.
var ruin: RefCounted
## Ladders in the current stage: {bottom, top, face}. Used by any stage.
var ladders: Array = []
var climb_ladder: Dictionary = {}
var climb_phase: float = 0.0
var climb_mask: int = 1
var fx: RefCounted
var village: RefCounted
var env_res: Environment
var sun: DirectionalLight3D
var grass: Array = []
var boss_name: String = "DARK KNIGHT"
var fail_text: String = "YOU FELL"
var win_text: String = "CITADEL CLEARED"
var hero: CharacterBody3D
var ally: CharacterBody3D
var boss: CharacterBody3D
var enemies: Array = []
var hud: Control
var camera: Camera3D
var mode: String = "title"
var section: int = 0
var checkpoint: int = 0
var barriers: Array = []
var hero_key: String = "blonde_lance"
var stamina: float = 100.0
var block_t: float = 0.0
var queued_attack: bool = false
var tokens: Array = []
var effects: Array = []
var waves: Array = []
var dead_timer: float = 0.0
var time_played: float = 0.0
var parries: int = 0
var said: Dictionary = {}
var audio_bank: Dictionary = {}
var muted: bool = false
var cam_pos: Vector3
var shake: float = 0.0
var mats: Dictionary = {}
var autotest: Node
var world: Node3D
var boss_seen: bool = false
var key_attack_prev: bool = false
## Sword drawn (in hand) or put away on the back. The village starts with it
## put away; ATTACK, GUARD or CHARGE draw it automatically.
var sword_out: bool = true
var draw_t: float = 0.0
var draw_target: bool = true
var draw_swapped: bool = true
const DRAW_TIME: float = 0.5
var key_jump_prev: bool = false
var mana: float = 100.0
var potions: int = 3
var potion_cd: float = 0.0
var charge: float = 0.0
var marks: Array = []
var bolts: Array = []
var burst_window: float = 0.0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.2
var air_dash_used: bool = false
var dodge_dir: Vector3 = Vector3.ZERO
var chain: Array = []
var chain_i: int = 0
var chain_from: Vector3
var chain_to: Vector3
var chain_power: float = 1.0
const DODGE_TIME: float = 0.3
const DODGE_SPEED: float = 15.0
const CHAIN_SEG: float = 0.24
# Stealth (ported from the MG build: Player.gd cover/crouch/crawl, Game.gd knock/noise).
var patrol: RefCounted
var walls: Array = []
var wall_heights: Dictionary = {}
var crouched: bool = false
var prone: bool = false
var cover: Dictionary = {}
var cover_side: float = 1.0
var cover_low: bool = false
var cover_cooldown: float = 0.0
var cover_blend: float = 0.0
var cover_motion: Vector3 = Vector3.ZERO
var peeking: bool = false
var peek_dir: Vector3 = Vector3.ZERO
var wall_pressure: float = 0.0
var foot_time: float = 0.0
var distract_cd: float = 0.0
var crouch_hold: float = 0.0
var crouch_long: bool = false
var takedowns: int = 0
var throws: Array = []
var cover_eye: Vector3 = Vector3.ZERO
var cover_look: Vector3 = Vector3.ZERO
## Phone performance mode: no glow, no real-time shadows or extra lights,
## lighter models, fewer particles. Auto on phones/touch; ?full or ?lite
## in the URL forces it off or on. ?fps shows the frame rate.
var phone: bool = false
var show_fps: bool = false
var fps_label: Label
var blob_tex: Texture2D

func url_has(word: String) -> bool:
	if not OS.has_feature("web"):
		return ("--" + word) in OS.get_cmdline_user_args()
	return str(JavaScriptBridge.eval("location.search", true)).contains(word)

func detect_phone() -> bool:
	if url_has("full"):
		return false
	if url_has("lite"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		return true
	return DisplayServer.is_touchscreen_available()

## Light model on phones: knight.glb -> knight_lite.glb etc.
func model_path(path: String) -> String:
	if not phone or path.ends_with("_lite.glb"):
		return path
	var lite: String = path.replace(".glb", "_lite.glb")
	return lite if ResourceLoader.exists(lite) else path

func _ready() -> void:
	phone = detect_phone()
	show_fps = url_has("fps")
	print("CITADEL performance mode: ", "PHONE" if phone else "FULL")
	patrol = PatrolScript.new(self)
	forest = ForestScript.new(self)
	ruin = RuinScript.new(self)
	fx = FxScript.new(self)
	village = VillageScript.new(self)
	setup_input()
	for cue: String in ["hit", "hurt", "knock", "alarm", "win", "fail", "hook", "guard_down", "explosion", "pulse", "chip", "cover", "step", "bleep"]:
		audio_bank[cue] = load("res://audio/%s.wav" % cue)
	build_environment()
	world = Node3D.new()
	add_child(world)
	# Direct links: ?village or ?forest opens the title with that stage picked.
	if url_has("village"):
		stage = "village"
		village.enter()
	elif url_has("forest"):
		stage = "forest"
	build_stage()
	camera = Camera3D.new()
	camera.fov = 54
	camera.far = 600
	add_child(camera)
	camera.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	if show_fps:
		fps_label = Label.new()
		fps_label.position = Vector2(8, 8)
		fps_label.add_theme_font_size_override("font_size", 22)
		fps_label.add_theme_color_override("font_color", Color("7dffcf"))
		fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fps_label.add_theme_constant_override("outline_size", 6)
		fps_label.z_index = 100
	hud = HUDScript.new()
	hud.game = self
	layer.add_child(hud)
	if fps_label:
		layer.add_child(fps_label)
	spawn_cast()
	cam_pos = hero.global_position
	var web_test: bool = false
	if OS.has_feature("web"):
		web_test = str(JavaScriptBridge.eval("location.search", true)).contains("autotest")
		print("CITADEL web search check: ", web_test)
	if "--autotest" in OS.get_cmdline_user_args() or web_test:
		autotest = AutoTestScript.new()
		autotest.game = self
		add_child(autotest)

func setup_input() -> void:
	var keys: Dictionary = {"cc_left": [KEY_A, KEY_LEFT], "cc_right": [KEY_D, KEY_RIGHT], "cc_up": [KEY_W, KEY_UP], "cc_down": [KEY_S, KEY_DOWN], "cc_jump": [KEY_SPACE], "cc_attack": [KEY_J], "cc_block": [KEY_K, KEY_SHIFT], "cc_pause": [KEY_ESCAPE, KEY_P], "cc_dodge": [KEY_L], "cc_skill": [KEY_I], "cc_magic": [KEY_U], "cc_potion": [KEY_R], "cc_crouch": [KEY_C], "cc_hug": [KEY_H], "cc_peek": [KEY_Q], "cc_distract": [KEY_F], "cc_crawl": [KEY_Z], "cc_sheathe": [KEY_X], "cc_talk": [KEY_T]}
	for n: String in keys:
		if InputMap.has_action(n):
			continue
		InputMap.add_action(n)
		for code: int in keys[n]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(n, ev)
	var pad: Dictionary = {"cc_jump": JOY_BUTTON_A, "cc_attack": JOY_BUTTON_X, "cc_block": JOY_BUTTON_RIGHT_SHOULDER, "cc_pause": JOY_BUTTON_START, "cc_dodge": JOY_BUTTON_B, "cc_skill": JOY_BUTTON_Y, "cc_magic": JOY_BUTTON_LEFT_SHOULDER, "cc_potion": JOY_BUTTON_DPAD_UP}
	for n: String in pad:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = pad[n]
		InputMap.action_add_event(n, ev)

func sound(cue: String, db: float = -8.0) -> void:
	if muted or not audio_bank.has(cue):
		return
	var n: AudioStreamPlayer = AudioStreamPlayer.new()
	n.stream = audio_bank[cue]
	n.volume_db = db
	add_child(n)
	n.finished.connect(n.queue_free)
	n.play()

func paused() -> bool:
	return mode != "play" and mode != "dead"

# ---------------------------------------------------------------- world

func build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2f63c9")
	sm.sky_horizon_color = Color("c9dcff")
	sm.ground_horizon_color = Color("c9dcff")
	sm.ground_bottom_color = Color("e9f1ff")
	sm.sun_angle_max = 20
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("aebfe0")
	e.ambient_light_energy = 0.6
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.82
	e.fog_enabled = true
	e.fog_light_color = Color("cfe0ff")
	e.fog_density = 0.0022
	e.fog_sky_affect = 0.0
	e.glow_enabled = not phone
	e.glow_intensity = 0.35
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.3
	# Richer, less washed-out colour like the concept screens.
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.12
	e.adjustment_saturation = 1.3
	env.environment = e
	add_child(env)
	env_res = e
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.15
	sun.light_color = Color("fff3dc")
	sun.shadow_enabled = not phone
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

func citadel_look() -> void:
	var sm: ProceduralSkyMaterial = env_res.sky.sky_material
	sm.sky_top_color = Color("2f63c9")
	sm.sky_horizon_color = Color("c9dcff")
	sm.ground_horizon_color = Color("c9dcff")
	sm.ground_bottom_color = Color("e9f1ff")
	env_res.fog_light_color = Color("cfe0ff")
	env_res.fog_density = 0.0022
	env_res.ambient_light_color = Color("aebfe0")
	env_res.ambient_light_energy = 0.6
	env_res.tonemap_exposure = 0.82
	sun.light_energy = 1.15
	sun.light_color = Color("fff3dc")
	sun.rotation_degrees = Vector3(-52, -28, 0)

## Rebuild the level for the current stage.
func build_stage() -> void:
	for c: Node in world.get_children():
		world.remove_child(c)
		c.queue_free()
	walls.clear()
	wall_heights.clear()
	barriers.clear()
	grass.clear()
	ladders.clear()
	if stage == "citadel":
		ruin.build()
	elif stage == "forest":
		sections = ForestScript.SECTIONS
		map_zones = ForestScript.MAP_ZONES
		win_text = "ESCAPED THE FOREST"
		forest.build()
	elif stage == "village":
		village.configure_stage()
		village.build()
	else:
		sections = SECTIONS
		map_zones = CITADEL_ZONES
		boss_name = "DARK KNIGHT"
		win_text = "CITADEL CLEARED"
		citadel_look()
		build_world()

func hero_in_grass() -> bool:
	var p: Vector2 = Vector2(hero.global_position.x, hero.global_position.z)
	for g: Rect2 in grass:
		if g.has_point(p):
			return true
	return false

func target_for(e: CharacterBody3D) -> CharacterBody3D:
	## In the forest, knights go for Eliza when she is the closer one.
	if stage == "forest" and ally != null and ally.alive() and hero.alive():
		if ally.global_position.distance_to(e.global_position) + 1.5 < hero.global_position.distance_to(e.global_position):
			return ally
	return hero

func marble_texture(dark: bool) -> ImageTexture:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.012
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 4
	n.seed = 7 if dark else 3
	var img: Image = n.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGB8)
	var base: Color = Color("1c1a26") if dark else Color("c4c1bb")
	var vein: Color = Color("4a3878") if dark else Color("8e98ab")
	var gold: Color = Color("d5ad55")
	for y in 256:
		for x in 256:
			var v: float = img.get_pixel(x, y).r
			var c: Color = base.lerp(vein, pow(clampf(v, 0, 1), 2.5) * 0.85)
			if x < 3 or y < 3:
				c = gold
			elif x % 128 < 2 or y % 128 < 2:
				c = c.lerp(Color("6f6a62"), 0.5)
			elif (x + y) % 128 < 2 or absi(x - y) % 128 < 2:
				c = c.lerp(gold, 0.35)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func banner_texture() -> ImageTexture:
	var img: Image = Image.create(64, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color("1c2a78"))
	for y in 160:
		for x in 64:
			var c: Color = img.get_pixel(x, y)
			if x < 4 or x > 59:
				c = Color("d5ad55")
			var cx: float = (x - 32.0) / 18.0
			var cy: float = (y - 62.0) / 26.0
			var r: float = sqrt(cx * cx + cy * cy)
			var star: float = absf(cos(atan2(cy, cx) * 4.0))
			if r < 0.35 + star * 0.65 and r > 0.15 + star * 0.5:
				c = Color("e6c46a")
			if y > 140 and (x / 8) % 2 == (y / 6) % 2:
				c = Color("d5ad55")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func mat(id: String) -> StandardMaterial3D:
	if mats.has(id):
		return mats[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	match id:
		"marble":
			m.albedo_texture = marble_texture(false)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)
			m.roughness = 0.45
			m.metallic_specular = 0.35
		"darkmarble":
			m.albedo_texture = marble_texture(true)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)
			m.roughness = 0.35
			m.metallic_specular = 0.4
		"stone":
			m.albedo_color = Color("c9c5bd")
			m.roughness = 0.7
		"wood":
			m.albedo_color = Color("6b4a2c")
			m.roughness = 0.85
		"gold":
			m.albedo_color = Color("d5ad55")
			m.metallic = 0.85
			m.roughness = 0.3
		"banner":
			m.albedo_texture = banner_texture()
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.8
		"crystal":
			m.albedo_color = Color(0.55, 0.85, 1.0, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("4fd8ff")
			m.emission_energy_multiplier = 2.2
			m.roughness = 0.05
		"violet":
			m.albedo_color = Color(0.75, 0.55, 1.0, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("9d5bff")
			m.emission_energy_multiplier = 2.4
		"hedge":
			m.albedo_color = Color("4f7a3a")
			m.roughness = 0.9
		"rock":
			m.albedo_color = Color("b9b2a6")
			m.roughness = 0.95
		"roof":
			m.albedo_color = Color("2b4fb8")
			m.roughness = 0.5
		"barrier":
			m.albedo_color = Color(0.35, 0.85, 1.0, 0.28)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("4fd8ff")
			m.emission_energy_multiplier = 1.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"cloud":
			m.albedo_color = Color(1, 1, 1, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"water":
			m.albedo_color = Color(0.85, 0.95, 1.0, 0.6)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("bfe9ff")
			m.emission_energy_multiplier = 0.6
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats[id] = m
	return m

func box(pos: Vector3, size: Vector3, material: String, collide: bool = true, parent: Node3D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(material)
	mi.position = pos
	(parent if parent else world).add_child(mi)
	if collide and material != "barrier" and pos.y - size.y * 0.5 < 0.35 and pos.y + size.y * 0.5 > 0.7:
		add_wall(Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z), pos.y + size.y * 0.5)
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi

func add_wall(r: Rect2, top: float) -> void:
	walls.append(r)
	wall_heights[r] = top

func column(pos: Vector3, h: float, r: float = 0.55, collide: bool = true) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.05
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat("stone")
	mi.position = pos + Vector3(0, h * 0.5, 0)
	world.add_child(mi)
	box(pos + Vector3(0, 0.2, 0), Vector3(r * 2.6, 0.4, r * 2.6), "marble", false)
	box(pos + Vector3(0, h - 0.15, 0), Vector3(r * 2.6, 0.3, r * 2.6), "gold", false)
	if collide:
		add_wall(Rect2(pos.x - r * 1.05, pos.z - r * 1.05, r * 2.1, r * 2.1), h)
		var body: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: CylinderShape3D = CylinderShape3D.new()
		sh.radius = r * 1.1
		sh.height = h
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)

func banner(pos: Vector3, facing: float, h: float = 4.0) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(h * 0.4, h)
	mi.mesh = q
	mi.material_override = mat("banner")
	mi.position = pos
	mi.rotation.y = facing
	world.add_child(mi)

func crystal(pos: Vector3, s: float = 1.0, violet: bool = false) -> void:
	box(pos + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9) * s, "marble", true)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PrismMesh = PrismMesh.new()
	pm.size = Vector3(0.6, 1.6, 0.6) * s
	mi.mesh = pm
	mi.material_override = mat("violet" if violet else "crystal")
	mi.position = pos + Vector3(0, (0.9 + 0.8) * s, 0)
	mi.rotation.y = 0.6
	world.add_child(mi)
	var down: MeshInstance3D = mi.duplicate()
	down.rotation.z = PI
	down.position = pos + Vector3(0, (0.9 + 0.8 - 1.25) * s + 0.2, 0)
	down.scale = Vector3(1, 0.35, 1)
	world.add_child(down)
	if phone:
		return
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("9d5bff") if violet else Color("6fe0ff")
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = pos + Vector3(0, 2.2 * s, 0)
	world.add_child(light)

func tower(pos: Vector3, r: float, h: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat("stone")
	mi.position = pos + Vector3(0, h * 0.5, 0)
	world.add_child(mi)
	var roof: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = r * 1.25
	cone.height = r * 3.2
	cone.radial_segments = 10
	roof.mesh = cone
	roof.material_override = mat("roof")
	roof.position = pos + Vector3(0, h + r * 1.6, 0)
	world.add_child(roof)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var rc: CylinderMesh = CylinderMesh.new()
	rc.top_radius = r * 1.12
	rc.bottom_radius = r * 1.12
	rc.height = 0.3
	ring.mesh = rc
	ring.material_override = mat("gold")
	ring.position = pos + Vector3(0, h, 0)
	world.add_child(ring)

func island(pos: Vector3, r: float) -> void:
	var rock: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = r
	cone.bottom_radius = 0.0
	cone.height = r * 1.8
	cone.radial_segments = 8
	rock.mesh = cone
	rock.material_override = mat("rock")
	rock.position = pos - Vector3(0, r * 0.9, 0)
	world.add_child(rock)
	var top: MeshInstance3D = MeshInstance3D.new()
	var tc: CylinderMesh = CylinderMesh.new()
	tc.top_radius = r * 0.98
	tc.bottom_radius = r
	tc.height = 0.6
	top.mesh = tc
	top.material_override = mat("marble")
	top.position = pos
	world.add_child(top)
	var count: int = 2 + int(r) % 3
	for i in count:
		var a: float = float(i) / count * TAU + r
		tower(pos + Vector3(cos(a), 0, sin(a)) * r * 0.45, r * 0.12, r * (0.7 + 0.3 * float(i % 2)))
	var fall: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(r * 0.3, r * 2.0)
	fall.mesh = q
	fall.material_override = mat("water")
	fall.position = pos + Vector3(0, -r, r * 0.9)
	world.add_child(fall)

func build_world() -> void:
	# Section 0: courtyard (z 4 .. -38).
	box(Vector3(0, -0.5, -13), Vector3(26, 1, 52), "marble")
	box(Vector3(-13.5, 4, -13), Vector3(1, 9, 52), "marble")
	box(Vector3(13.5, 4, -13), Vector3(1, 9, 52), "marble")
	box(Vector3(0, 4, 12.5), Vector3(28, 9, 1), "marble")
	for z in [-2.0, -10.0, -18.0, -26.0, -34.0]:
		column(Vector3(-11.5, 0, z), 7.0)
		column(Vector3(11.5, 0, z), 7.0)
		banner(Vector3(-12.95, 4.6, z - 4.0), PI / 2.0)
		banner(Vector3(12.95, 4.6, z - 4.0), -PI / 2.0)
	for p: Vector3 in [Vector3(-6, 0, -9), Vector3(6, 0, -13), Vector3(-5, 0, -25), Vector3(7, 0, -28)]:
		box(p + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 1.4), "marble")
		box(p + Vector3(0, 1.1, 0), Vector3(2.9, 0.5, 1.1), "hedge", false)
	crystal(Vector3(-9, 0, -18), 1.0)
	crystal(Vector3(9, 0, -4), 1.0)
	# Gate into the bridge.
	box(Vector3(-7.75, 4, -38.5), Vector3(11.5, 9, 1), "marble")
	box(Vector3(7.75, 4, -38.5), Vector3(11.5, 9, 1), "marble")
	box(Vector3(0, 7.2, -38.5), Vector3(4.2, 2.6, 1.2), "gold", false)
	tower(Vector3(-4.2, 0, -38.5), 0.9, 9.5)
	tower(Vector3(4.2, 0, -38.5), 0.9, 9.5)
	# Section 1: broken sky bridge (z -38 .. -92). Two gaps to jump.
	var segs: Array = [[-38.0, -52.0], [-54.6, -68.0], [-70.8, -92.0]]
	for s: Array in segs:
		var len: float = absf(s[1] - s[0])
		var mid: float = (s[0] + s[1]) * 0.5
		box(Vector3(0, -0.5, mid), Vector3(7, 1, len), "marble")
		box(Vector3(0, -1.6, mid), Vector3(5.4, 1.4, len - 0.4), "stone", false)
		box(Vector3(-3.35, 0.55, mid), Vector3(0.3, 1.1, len), "stone")
		box(Vector3(3.35, 0.55, mid), Vector3(0.3, 1.1, len), "stone")
		var z: float = s[0] - 1.5
		while z > s[1] + 1.0:
			box(Vector3(-3.35, 1.25, z), Vector3(0.45, 0.3, 0.45), "gold", false)
			box(Vector3(3.35, 1.25, z), Vector3(0.45, 0.3, 0.45), "gold", false)
			z -= 3.0
	for gz: float in [-53.3, -69.4]:
		for side: float in [-1.0, 1.0]:
			box(Vector3(side * 2.2, -0.9, gz + 1.3), Vector3(1.6, 0.8, 0.5), "stone", false)
	banner(Vector3(-3.6, 2.6, -60), PI / 2.0, 3.0)
	banner(Vector3(3.6, 2.6, -80), -PI / 2.0, 3.0)
	# Cloud sea under the bridge.
	for i in 14:
		var c: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(60, 60)
		c.mesh = q
		c.material_override = mat("cloud")
		c.rotation.x = -PI / 2.0
		c.position = Vector3(randf_range(-80, 80), -22 - i * 0.6, randf_range(-160, 20))
		world.add_child(c)
	# Section 2: plaza (z -92 .. -128).
	box(Vector3(0, -0.5, -110), Vector3(28, 1, 36), "marble")
	box(Vector3(-14.5, 0.6, -110), Vector3(1, 1.2, 36), "stone")
	box(Vector3(14.5, 0.6, -110), Vector3(1, 1.2, 36), "stone")
	box(Vector3(-9, 0.6, -92.4), Vector3(10, 1.2, 0.6), "stone")
	box(Vector3(9, 0.6, -92.4), Vector3(10, 1.2, 0.6), "stone")
	for p: Vector3 in [Vector3(-8, 0, -100), Vector3(8, 0, -100), Vector3(-8, 0, -120), Vector3(8, 0, -120)]:
		crystal(p, 1.2)
	for z in [-96.0, -106.0, -116.0, -126.0]:
		column(Vector3(-12.5, 0, z), 6.0, 0.5)
		column(Vector3(12.5, 0, z), 6.0, 0.5)
	box(Vector3(0, 0.15, -110), Vector3(6, 0.3, 6), "gold", false)
	box(Vector3(0, 0.35, -110), Vector3(5.4, 0.3, 5.4), "marble", false)
	# Section 3: throne hall (z -128 .. -170), darker, violet crystals.
	box(Vector3(0, -0.5, -150), Vector3(24, 1, 44), "darkmarble")
	box(Vector3(-12.5, 6, -150), Vector3(1, 13, 44), "darkmarble")
	box(Vector3(12.5, 6, -150), Vector3(1, 13, 44), "darkmarble")
	box(Vector3(0, 6, -172.5), Vector3(26, 13, 1), "darkmarble")
	box(Vector3(-8.25, 6, -128.5), Vector3(8.5, 13, 1), "darkmarble")
	box(Vector3(8.25, 6, -128.5), Vector3(8.5, 13, 1), "darkmarble")
	box(Vector3(0, 10.5, -128.5), Vector3(8, 4, 1.2), "gold", false)
	for z in [-136.0, -146.0, -156.0, -166.0]:
		column(Vector3(-9.5, 0, z), 11.0, 0.7)
		column(Vector3(9.5, 0, z), 11.0, 0.7)
		banner(Vector3(-11.95, 6.0, z + 4.5), PI / 2.0, 5.0)
		banner(Vector3(11.95, 6.0, z + 4.5), -PI / 2.0, 5.0)
	crystal(Vector3(-6, 0, -168), 1.6, true)
	crystal(Vector3(6, 0, -168), 1.6, true)
	box(Vector3(0, 0.6, -169), Vector3(4, 1.2, 3), "gold")
	box(Vector3(0, 2.4, -170.3), Vector3(2.4, 3.6, 0.6), "darkmarble", false)
	# Skyline: floating islands and distant spires.
	var spots: Array = [Vector3(-60, 18, -40), Vector3(70, 26, -70), Vector3(-90, 40, -140), Vector3(95, 14, -150), Vector3(-40, 55, -220), Vector3(40, 34, -240), Vector3(-120, 20, 10), Vector3(120, 46, -10), Vector3(0, 70, -300), Vector3(-75, -6, -95), Vector3(80, -10, -30)]
	for i in spots.size():
		island(spots[i], 8.0 + float(i % 4) * 4.0)
	for i in 9:
		tower(Vector3(-40 + i * 10, -4, -215 - float(i % 3) * 8.0), 2.0 + float(i % 2), 30.0 + float(i % 4) * 9.0)
	# Barriers that open as sections are cleared.
	add_barrier(Vector3(0, 2, -38.5), Vector3(4.0, 4.0, 0.4))
	add_barrier(Vector3(0, 2, -92.5), Vector3(8.0, 4.0, 0.4))
	add_barrier(Vector3(0, 2.5, -128.5), Vector3(8.0, 5.0, 0.4))

func add_barrier(pos: Vector3, size: Vector3) -> void:
	barriers.append(box(pos, size, "barrier", true))

func open_barrier(i: int) -> void:
	if i < barriers.size() and is_instance_valid(barriers[i]):
		barriers[i].queue_free()
		sound("pulse", -6)
		burst(barriers[i].global_position, Color("6fe0ff"), 40, 5.0)

# ---------------------------------------------------------------- cast

func make_fighter(k: String, model: String, h: float, blade: Color, blade_len: float, pos: Vector3) -> CharacterBody3D:
	var f: CharacterBody3D = CharacterBody3D.new()
	f.set_script(FighterScript)
	add_child(f)
	f.global_position = pos
	f.setup(self, k, model_path(model), h, blade, blade_len)
	if phone:
		add_blob(f, h)
	return f

## Soft dark disc under a character, standing in for a real shadow on phones.
func add_blob(f: Node3D, h: float) -> void:
	if blob_tex == null:
		var g: GradientTexture2D = GradientTexture2D.new()
		var gr: Gradient = Gradient.new()
		gr.set_color(0, Color(0, 0, 0, 0.55))
		gr.set_color(1, Color(0, 0, 0, 0))
		g.gradient = gr
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 64
		g.height = 64
		blob_tex = g
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE * h * 0.55
	q.orientation = PlaneMesh.FACE_Y
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = blob_tex
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.03, 0)
	mi.name = "Blob"
	f.add_child(mi)

func spawn_cast() -> void:
	sword_out = stage != "village"
	draw_t = 0.0
	draw_swapped = true
	if stage == "forest":
		forest.spawn_cast()
		return
	if stage == "village":
		village.spawn_cast()
		return
	if stage == "citadel":
		ruin.spawn_cast()
		return
	boss_name = "DARK KNIGHT"
	var h: Dictionary = HEROES[hero_key]
	hero = make_fighter("hero", h.model, 1.8, h.blade, 1.25, sections[0].spawn)
	hero.max_hp = 100
	hero.hp = 100
	ally = make_fighter("ally", "res://assets/characters/eliza.glb", 1.7, Color("bfe9ff"), 0.5, sections[0].spawn + Vector3(1.6, 0, 2.4))
	ally.rig.sword.visible = false
	var knights: Array = [
		[0, Vector3(-9, 0.2, -17)], [0, Vector3(10, 0.2, -21)], [0, Vector3(-2, 0.2, -35)],
		[1, Vector3(0, 0.2, -60)], [1, Vector3(-1, 0.2, -78)], [1, Vector3(1.2, 0.2, -84)],
		[2, Vector3(-5, 0.2, -104)], [2, Vector3(5, 0.2, -106)], [2, Vector3(-3, 0.2, -118)], [2, Vector3(4, 0.2, -121)],
	]
	for k: Array in knights:
		var e: CharacterBody3D = make_fighter("knight", "res://assets/characters/knight_lite.glb", 1.82, Color("c8d0dc"), 0.95, k[1])
		e.section = k[0]
		e.max_hp = 70
		e.hp = 70
		e.yaw = PI
		e.home = k[1]
		enemies.append(e)
	# Courtyard guards patrol with vision cones, ported from the MG guards.
	var routes: Array = [
		[Vector2(-9, -17), Vector2(3, -17)],
		[Vector2(10, -21), Vector2(10, -33), Vector2(3, -33), Vector2(3, -21)],
		[Vector2(-2, -35), Vector2(-9, -31), Vector2(-2, -27)],
	]
	for i in routes.size():
		patrol.setup(enemies[i], routes[i])
	boss = make_fighter("boss", "res://assets/characters/knight.glb", 2.55, Color("ff3346"), 1.6, Vector3(0, 0.2, -158))
	boss.section = 3
	boss.max_hp = 650
	boss.hp = 650
	boss.dmg = 18
	boss.reach = 3.1
	boss.move_speed = 4.2
	boss.yaw = PI
	boss.home = boss.global_position
	enemies.append(boss)
	if phone:
		return
	var aura: OmniLight3D = OmniLight3D.new()
	aura.light_color = Color("ff3346")
	aura.light_energy = 1.6
	aura.omni_range = 5.0
	aura.position = Vector3(0, 2.0, 0)
	boss.add_child(aura)

func restart_with(key: String, new_stage: String = "") -> void:
	hero_key = key
	if village.active:
		village.leave()
	if new_stage != "":
		stage = new_stage
	if stage == "village":
		village.enter()
	for e: Node in enemies:
		e.queue_free()
	enemies.clear()
	hero.queue_free()
	ally.queue_free()
	for t: Dictionary in throws:
		if is_instance_valid(t.node):
			t.node.queue_free()
	throws.clear()
	hud.lines.clear()
	hud.popups.clear()
	hud.numbers.clear()
	build_stage()
	section = 0
	checkpoint = 0
	said.clear()
	tokens.clear()
	time_played = 0
	parries = 0
	boss_seen = false
	stamina = 100
	mana = 100
	potions = 3
	charge = 0
	marks.clear()
	for b: Dictionary in bolts:
		if is_instance_valid(b.node):
			b.node.queue_free()
	bolts.clear()
	cam_yaw = 0.0
	cam_pitch = 0.2
	crouched = false
	prone = false
	cover.clear()
	peeking = false
	takedowns = 0
	spawn_cast()
	cam_pos = hero.global_position

func start_game() -> void:
	mode = "play"
	hud.release()
	if stage == "forest":
		forest.start()
		return
	if stage == "village":
		village.start()
		return
	if stage == "citadel":
		ruin.start()
		return
	say_once("start", "ally", "Guards ahead. Stay sharp!")
	say_once("tip", "tip", "Hold BLOCK when a knight glows red. Block just before the hit to parry.")

# ---------------------------------------------------------------- loop

func _process(dt: float) -> void:
	if Input.is_action_just_pressed("cc_pause") and mode in ["play", "paused"]:
		mode = "paused" if mode == "play" else "play"
		hud.release()
	update_camera(dt)
	update_effects(dt)
	if mode == "play":
		time_played += dt
		progress_check()
	if mode == "dead":
		dead_timer += dt
	hud.queue_redraw()
	if fps_label:
		fps_label.text = "%d FPS  %s" % [Engine.get_frames_per_second(), "PHONE" if phone else "FULL"]

func cam_forward() -> Vector3:
	return Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))

func cam_right() -> Vector3:
	return Vector3(cos(cam_yaw), 0, -sin(cam_yaw))

## Steady follow camera that orbits only when the player drags the right side.
func update_camera(dt: float) -> void:
	if hero == null:
		return
	if mode == "play":
		var look_d: Vector2 = hud.take_look()
		cam_yaw -= look_d.x * 0.0065
		cam_pitch = clampf(cam_pitch + look_d.y * 0.004, 0.02, 1.1)
	# Close over-the-shoulder view like the concept screens: the hero fills
	# the lower-left, the fight reads in the centre.
	var dist: float = 2.75
	if stage == "classic" and section >= 3 and hero.global_position.z < -130:
		dist = 4.4
	elif stage == "citadel" and ruin.in_core():
		dist = 4.4
	var back: Vector3 = -cam_forward() * dist * cos(cam_pitch) + Vector3.UP * (dist * sin(cam_pitch) + 0.95) + cam_right() * 0.62
	cam_pos = cam_pos.lerp(hero.global_position, 1.0 - exp(-7.0 * dt))
	var jitter: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25
	shake = maxf(0.0, shake - dt * 3.0)
	var look: Vector3 = cam_pos + Vector3(0, 1.3, 0) + cam_forward() * 3.0 + cam_right() * 0.3
	var eye: Vector3 = cam_pos + back
	if prone:
		eye.y -= 1.0
		look.y -= 0.7
	elif crouched:
		eye.y -= 0.5
		look.y -= 0.4
	# Wall-hug view from the MG EnvironmentCamera: stand off the wall, and
	# shift toward the open side only while sliding or peeking.
	cover_blend = move_toward(cover_blend, 1.0 if in_cover() else 0.0, dt / 0.4)
	if cover_blend > 0.0 and in_cover():
		var normal: Vector3 = Vector3(cover.normal.x, 0, cover.normal.y)
		var tangent: Vector3 = Vector3(-normal.z, 0, normal.x) * cover_side
		var amount: float = 1.0 if cover_motion.length() > 0.1 or peek_dir.length() > 0.1 else 0.0
		var reveal: Vector3 = tangent * 1.4 * amount + peek_dir * 2.0
		var c_eye: Vector3 = hero.global_position + normal * 5.5 - tangent * 3.0 * amount + Vector3.UP * (2.2 if cover_low else 2.8)
		var c_look: Vector3 = hero.global_position + Vector3.UP * (0.8 if cover_low else 1.2) + reveal
		var k: float = cover_blend * cover_blend * (3.0 - 2.0 * cover_blend)
		cover_eye = cover_eye.lerp(c_eye, 1.0 - exp(-8.0 * dt)) if cover_eye != Vector3.ZERO else c_eye
		cover_look = cover_look.lerp(c_look, 1.0 - exp(-8.0 * dt)) if cover_look != Vector3.ZERO else c_look
		eye = eye.lerp(cover_eye, k)
		look = look.lerp(cover_look, k)
	else:
		cover_eye = Vector3.ZERO
		cover_look = Vector3.ZERO
	# Keep the camera out of walls and pillars.
	var head: Vector3 = hero.global_position + Vector3.UP * 1.4
	var block: Dictionary = ray(head, eye)
	if not block.is_empty():
		eye = (block.position as Vector3) + (head - eye).normalized() * 0.3
	camera.look_at_from_position(eye + jitter, look + jitter)

func move_input() -> Vector2:
	var v: Vector2 = hud.stick
	var k: Vector2 = Vector2(Input.get_action_strength("cc_right") - Input.get_action_strength("cc_left"), Input.get_action_strength("cc_down") - Input.get_action_strength("cc_up"))
	if k.length() > 0.1:
		v = k.limit_length(1.0)
	var pad: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pad.length() > 0.2:
		v = pad.limit_length(1.0)
	return v

func hero_tick(f: CharacterBody3D, dt: float) -> void:
	var mv: Vector2 = move_input()
	var key_attack: bool = Input.is_action_pressed("cc_attack")
	var key_jump: bool = Input.is_action_pressed("cc_jump")
	var attack: bool = hud.take("attack") or (key_attack and not key_attack_prev)
	var jump: bool = hud.take("jump") or (key_jump and not key_jump_prev)
	key_attack_prev = key_attack
	key_jump_prev = key_jump
	var blocking: bool = hud.held("block") or Input.is_action_pressed("cc_block")
	if mode != "play":
		attack = false
		jump = false
		blocking = false
		mv = Vector2.ZERO
	if f.state != "block":
		stamina = minf(100.0, stamina + dt * 28.0)
	if f.global_position.y < fall_line() and f.alive() and f.state != "climb":
		fell()
		return
	var dir: Vector3 = cam_right() * mv.x - cam_forward() * mv.y
	if climb_tick(f, dt, mv, dir, jump):
		return
	var dodge: bool = hud.take("dodge") or Input.is_action_just_pressed("cc_dodge")
	var magic: bool = hud.take("magic") or Input.is_action_just_pressed("cc_magic")
	var potion: bool = hud.take("potion") or Input.is_action_just_pressed("cc_potion")
	var skill_held: bool = hud.held("skill") or Input.is_action_pressed("cc_skill")
	var skill_up: bool = hud.took_release("skill") or Input.is_action_just_released("cc_skill")
	hud.take("skill")
	if mode != "play":
		dodge = false
		magic = false
		potion = false
		skill_held = false
		skill_up = false
	var talk: bool = hud.take("talk") or Input.is_action_just_pressed("cc_talk")
	if talk and mode == "play" and stage == "village" and village.active:
		if village.chat.is_open():
			village.chat.stop()
		else:
			village.chat.start(village.chat.nearest())
	var toggle: bool = hud.take("sheathe") or Input.is_action_just_pressed("cc_sheathe")
	if mode != "play":
		toggle = false
	sword_tick(f, dt, toggle, attack or blocking or skill_held)
	if not sword_out or draw_t > 0.0:
		attack = false
		blocking = false
		skill_held = false
		skill_up = false
	mana = minf(100.0, mana + dt * 4.0)
	potion_cd -= dt
	burst_window -= dt
	if f.is_on_floor():
		air_dash_used = false
	if f.state == "block":
		block_t += dt
	if not f.alive():
		charge = 0.0
		return
	if potion and potions > 0 and potion_cd <= 0 and f.hp < f.max_hp:
		potions -= 1
		potion_cd = 0.8
		f.hp = minf(f.max_hp, f.hp + 40.0)
		burst(f.global_position + Vector3.UP, Color("7dffcf"), 26, 3.0)
		ring(f.global_position + Vector3.UP * 0.1, 1.6, Color("7dffcf"), 0.5)
		sound("chip", -6)
		hud.popup("+40", Color("7dffcf"))
	if magic and f.state not in ["stagger", "hurt"]:
		cast_magic(f)
	# Charged attack: hold to build, release to dash-slash through the marks.
	if skill_held and f.state in ["idle", "block"]:
		charge = minf(1.0, charge + dt / 0.8)
		if charge >= 1.0 and not said.has("charged"):
			said["charged"] = true
			sound("pulse", -12)
	if skill_up:
		if charge >= 0.3 and f.state in ["idle", "block"]:
			start_chain(f, charge)
		charge = 0.0
	if not skill_held and not skill_up:
		charge = 0.0
	if dodge and f.state in ["idle", "block", "attack"] and stamina >= 18.0 and (f.is_on_floor() or not air_dash_used):
		if not f.is_on_floor():
			air_dash_used = true
		stamina -= 18.0
		dodge_dir = dir.normalized() if dir.length() > 0.2 else f.forward()
		f.yaw = atan2(-dodge_dir.x, -dodge_dir.z)
		f.rig.trail_on = false
		f.set_state("dodge", DODGE_TIME)
		sound("hook", -12)
	stealth_input(f, dt)
	if f.state != "idle" and (prone or in_cover()) and f.state not in ["block"]:
		leave_stance()
	match f.state:
		"dead":
			return
		"dodge":
			f.velocity.x = dodge_dir.x * DODGE_SPEED
			f.velocity.z = dodge_dir.z * DODGE_SPEED
			if not f.is_on_floor():
				f.velocity.y = maxf(f.velocity.y, 0.5)
			if f.state_t >= f.state_len:
				f.state = "idle"
				f.velocity.x *= 0.3
				f.velocity.z *= 0.3
			return
		"dashchain":
			chain_tick(f, dt)
			return
		"hurt", "stagger":
			f.velocity.x = move_toward(f.velocity.x, 0, 14 * dt)
			f.velocity.z = move_toward(f.velocity.z, 0, 14 * dt)
			if f.state_t >= f.state_len:
				f.state = "idle"
			return
		"attack":
			var hit_at: float = f.state_len * (0.5 if f.combo < 2 else 0.55)
			if f.state_t < hit_at * 0.8:
				aim_assist(f, dt)
			var lunge: float = 5.0 if f.state_t < hit_at else 0.0
			f.velocity.x = f.forward().x * lunge + dir.x * 1.0
			f.velocity.z = f.forward().z * lunge + dir.z * 1.0
			f.rig.trail_on = f.state_t > hit_at * 0.6 and f.state_t < hit_at * 1.5
			if attack and f.state_t > hit_at * 0.5:
				queued_attack = true
			if not f.hit_done and f.state_t >= hit_at:
				f.hit_done = true
				var dmg: float = 22.0 if f.combo < 2 else 34.0
				hero_strike(f, dmg, 2.7, 0.15, 0.7 if f.combo == 2 else 0.28)
			if f.state_t >= f.state_len:
				f.rig.trail_on = false
				if queued_attack and f.combo < 2:
					queued_attack = false
					f.combo += 1
					f.set_state("attack", 0.36 if f.combo == 1 else 0.5)
				else:
					queued_attack = false
					f.state = "idle"
					f.combo = 0
			return
		"plunge":
			f.rig.trail_on = true
			f.velocity.x = move_toward(f.velocity.x, 0, 8 * dt)
			f.velocity.z = move_toward(f.velocity.z, 0, 8 * dt)
			if f.state_t < 0.18:
				f.velocity.y = 2.0
			else:
				f.velocity.y = -22.0
			if f.state_t > 0.2 and f.is_on_floor():
				f.rig.trail_on = false
				hero_strike(f, 38.0, 3.4, -1.0, 0.8)
				ring(f.global_position + Vector3.UP * 0.1, 3.4, Color("8fe9ff"), 0.35)
				fx.impact(f.global_position + Vector3.UP * 0.4, f.rig.blade_color, 2.6)
				fx.sparks(f.global_position + Vector3.UP * 0.2, f.rig.blade_color, 30, 10.0)
				shake = 0.8
				sound("explosion", -14)
				f.set_state("hurt", 0.28)
			return
		"block":
			f.velocity.x = dir.x * 1.6
			f.velocity.z = dir.z * 1.6
			if dir.length() > 0.2:
				f.face_toward(f.global_position + dir, dt, 6.0)
			if not blocking:
				f.state = "idle"
			elif attack:
				f.combo = 0
				f.set_state("attack", 0.36)
				sound("cover", -14)
			return
	# Free movement.
	var speed: float = 6.6
	if prone:
		speed = 1.4
	elif crouched:
		speed = 2.6
	if in_cover():
		cover_move(f, dt, mv, dir)
	else:
		f.velocity.x = dir.x * speed
		f.velocity.z = dir.z * speed
		if dir.length() > 0.15:
			f.face_toward(f.global_position + dir, dt, 14.0)
		auto_cover(f, dt, dir)
	footsteps(f, dt)
	if (jump or attack or blocking) and (prone or in_cover()):
		leave_stance()
		if prone:
			jump = false
	if jump and f.is_on_floor():
		if crouched:
			set_crouch(false)
		f.velocity.y = 9.6
		sound("step", -10)
	if attack:
		if crouched:
			set_crouch(false)
		if f.is_on_floor():
			f.combo = 0
			f.set_state("attack", 0.36)
			sound("cover", -14)
		else:
			f.set_state("plunge", 1.0)
			sound("cover", -12)
	elif blocking and f.is_on_floor():
		f.set_state("block")
		block_t = 0.0

func aim_assist(f: CharacterBody3D, dt: float) -> void:
	var best: CharacterBody3D = null
	var best_d: float = 4.2
	for e: CharacterBody3D in enemies:
		if not e.alive() or not e.visible:
			continue
		var d: float = e.global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		f.face_toward(best.global_position, dt, 18.0)

func hero_strike(f: CharacterBody3D, dmg: float, reach: float, arc_cos: float, stagger: float) -> void:
	var hit_any: bool = false
	for e: CharacterBody3D in enemies:
		if not e.alive() or not e.visible:
			continue
		var to: Vector3 = e.global_position - f.global_position
		to.y = 0
		var d: float = to.length()
		var r: float = reach + (0.6 if e.kind == "boss" else 0.0)
		if d > r or absf(e.global_position.y - f.global_position.y) > 2.2:
			continue
		if d > 0.3 and f.forward().dot(to.normalized()) < arc_cos:
			continue
		if e.stealth and not e.active and not e.seeing:
			# Unaware guard: one silent hit, like the old takedowns.
			e.damage(e.hp + 1.0, f.global_position, 0.0)
			takedowns += 1
			fx.sword_hit(f, e, Color("7dffcf"), true, 2)
			hud.popup("SILENT TAKEDOWN", Color("7dffcf"))
			hit_any = true
			continue
		wake(e)
		var heavy: bool = stagger >= 0.6
		e.damage(dmg, f.global_position, stagger)
		fx.sword_hit(f, e, f.rig.blade_color, heavy, f.combo if f.state == "attack" else 2)
		hit_any = true
	if hit_any:
		sound("hit", -6)
		shake = maxf(shake, 0.55 if stagger >= 0.6 else 0.35)
	else:
		sound("step", -16)

func enemy_hits(attacker: CharacterBody3D, dmg: float, reach: float, arc_cos: float) -> void:
	var f: CharacterBody3D = target_for(attacker)
	if f == ally:
		var ta: Vector3 = ally.global_position - attacker.global_position
		ta.y = 0
		if ta.length() <= reach and (ta.length() < 0.3 or attacker.forward().dot(ta.normalized()) >= arc_cos):
			ally.damage(dmg * 0.8, attacker.global_position, 0.3)
			ally.flash_color = Color(1, 0.3, 0.3)
			sound("hurt", -8)
			say_once("eliza_hit", "ally", "Lance! They're on me!")
		return
	if not f.alive():
		return
	if f.state in ["dodge", "dashchain"]:
		return
	var to: Vector3 = f.global_position - attacker.global_position
	to.y = 0
	var d: float = to.length()
	if d > reach or absf(f.global_position.y - attacker.global_position.y) > 1.6:
		return
	if d > 0.3 and attacker.forward().dot(to.normalized()) < arc_cos:
		return
	var facing_attacker: bool = f.forward().dot(-to.normalized()) > 0.2
	if f.state == "block" and facing_attacker:
		if block_t < 0.32:
			parries += 1
			attacker.set_state("stagger", 1.4 if attacker.kind != "boss" else 1.1)
			attacker.flash = 1.0
			attacker.flash_color = Color(0.5, 0.9, 1.0)
			fx.impact(f.rig.tip_world(), Color("8fe9ff"), 2.2)
			fx.sparks(f.rig.tip_world(), Color("ffffff"), 34, 11.0)
			fx.hitstop(0.12)
			ring(f.global_position + Vector3.UP * 1.1, 1.6, Color("8fe9ff"), 0.25)
			hud.popup("PARRY!", Color("8fe9ff"))
			sound("guard_down", -4)
			shake = 0.5
			if attacker.kind != "boss":
				give_token(attacker)
			return
		stamina -= dmg * 2.2
		fx.impact(f.rig.tip_world(), Color("ffe08a"), 0.9, false)
		fx.sparks(f.rig.tip_world(), Color("ffe08a"), 16, 7.0, -to.normalized() + Vector3.UP * 0.5)
		sound("knock", -6)
		f.velocity += to.normalized() * 3.0
		if stamina <= 0:
			stamina = 0
			f.set_state("stagger", 0.8)
			hud.popup("GUARD BROKEN", Color("ffb03b"))
			f.damage(dmg * 0.5, attacker.global_position, 0.0)
		return
	f.damage(dmg, attacker.global_position, 0.32)
	f.flash_color = Color(1, 0.3, 0.3)
	fx.slash(f.global_position + Vector3.UP * 1.1, f.global_position - attacker.global_position, Color("ff3346"), 1.4, 0.9)
	fx.sparks(f.global_position + Vector3.UP * 1.1, Color("ff6a5a"), 14, 6.0)
	hud.hurt_flash = 1.0
	sound("hurt", -6)
	shake = maxf(shake, 0.6)

func shockwave(pos: Vector3, rage: bool) -> void:
	sound("explosion", -4)
	shake = 1.0
	var r: Dictionary = ring(pos + Vector3.UP * 0.15, 13.0, Color("ff3346"), 1.05)
	r["damage"] = 22.0 if not rage else 28.0
	r["hit"] = false
	burst(pos + Vector3.UP * 0.3, Color("ff6a5a"), 30, 7.0)
	say_once("slam", "ally", "When he leaps, JUMP over the red shockwave!")

func ally_heal(a: CharacterBody3D) -> void:
	hero.hp = minf(hero.max_hp, hero.hp + 35.0)
	burst(hero.global_position + Vector3.UP * 1.0, Color("7dffcf"), 30, 3.0)
	ring(hero.global_position + Vector3.UP * 0.1, 1.8, Color("7dffcf"), 0.6)
	sound("chip", -6)
	say("ally", "Hold on, I've got you!")

func separation(me: CharacterBody3D) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for e: CharacterBody3D in enemies:
		if e == me or not e.alive():
			continue
		var d: Vector3 = me.global_position - e.global_position
		d.y = 0
		var l: float = d.length()
		if l < 1.4 and l > 0.001:
			push += d / l * (1.4 - l)
	var ahead: Vector3 = me.global_position + me.velocity.normalized() * 0.9 + Vector3.UP * 0.5
	if me.velocity.length() > 0.1 and ray(ahead, ahead + Vector3.DOWN * 3.0).is_empty():
		me.velocity.x = 0
		me.velocity.z = 0
	return push

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)

func take_token(e: CharacterBody3D) -> bool:
	if e in tokens:
		return true
	tokens = tokens.filter(func(t: Variant) -> bool: return is_instance_valid(t) and t.alive() and t.state in ["windup", "strike"])
	if tokens.size() >= 2:
		return false
	tokens.append(e)
	return true

func give_token(e: CharacterBody3D) -> void:
	tokens.erase(e)

func on_death(f: CharacterBody3D) -> void:
	give_token(f)
	marks.erase(f)
	if f == hero or f == ally:
		fail_text = "YOU FELL" if f == hero else "SHE WAS CAPTURED"
		mode = "dead"
		dead_timer = 0.0
		sound("fail", -6)
		return
	sound("guard_down", -8)
	burst(f.global_position + Vector3.UP, Color("ffd27a"), 24, 5.0)
	if f == boss and stage == "forest":
		hud.popup("BLONDE LANCE IS DOWN", Color("ffd27a"))
		return
	if f == boss:
		hud.popup("DARK KNIGHT DEFEATED", Color("ffd27a"))
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			mode = "win"
			sound("win", -4)
			hud.release())

func fell() -> void:
	hero.hp -= 15
	hud.popup("-15  FELL", Color("ff8a8a"))
	sound("hurt", -6)
	if hero.hp <= 0:
		hero.hp = 0
		hero.set_state("dead")
		on_death(hero)
	var safe: Vector3 = sections[checkpoint].spawn
	if checkpoint == 1 and stage == "classic":
		# Back to the last bridge segment the hero reached.
		var z: float = hero.global_position.z
		safe.z = -40.0 if z > -54 else (-56.5 if z > -70 else -72.5)
	hero.global_position = safe
	hero.velocity = Vector3.ZERO
	cam_pos = safe

func respawn() -> void:
	hero.hp = hero.max_hp
	hero.set_state("idle")
	hero.visible = true
	stamina = 100
	hero.global_position = sections[checkpoint].spawn
	hero.velocity = Vector3.ZERO
	ally.global_position = hero.global_position + Vector3(1.6, 0, 2.4)
	ally.hp = ally.max_hp
	ally.set_state("idle")
	ally.visible = true
	for e: CharacterBody3D in enemies.duplicate():
		if e.has_meta("reinforcement"):
			enemies.erase(e)
			e.queue_free()
	if stage == "forest":
		forest.reinforced.clear()
	for e: CharacterBody3D in enemies:
		if e.alive() and e.section >= checkpoint:
			e.hp = e.max_hp
			e.global_position = e.home
			e.velocity = Vector3.ZERO
			e.state = "idle"
			e.active = false
			e.attack_cd = 1.5
			if e.stealth:
				e.gstate = "PATROL"
				e.suspicion = 0.0
				if e.kind == "hunter":
					var r0: Vector2 = e.route[0]
					e.global_position = Vector3(r0.x, 0.2, r0.y)
	tokens.clear()
	marks.clear()
	mana = 100
	cam_pos = hero.global_position
	mode = "play"
	hud.release()

func fall_line() -> float:
	if stage == "citadel":
		return ruin.fall_line()
	return -9.0

## Ladders: walk into one and push forward to climb (stick up/down while on it).
## The climber moves straight up the rails with collisions off, so ledges and
## overhangs never snag; at the top they step onto the landing. JUMP lets go.
func climb_tick(f: CharacterBody3D, dt: float, mv: Vector2, dir: Vector3, jump: bool) -> bool:
	if f.state == "climb":
		var l: Dictionary = climb_ladder
		var bottom: Vector3 = l.bottom
		var top: Vector3 = l.top
		var face: Vector3 = l.face
		var v: float = -mv.y
		if dir.length() > 0.2 and absf(mv.y) < 0.2:
			v = clampf(dir.normalized().dot(face), -1.0, 1.0)
		f.velocity = Vector3.ZERO
		var y: float = f.global_position.y + v * 3.0 * dt
		climb_phase += absf(v) * dt * 5.5
		f.yaw = atan2(-face.x, -face.z)
		if jump:
			end_climb(f, f.global_position - face * 0.4)
			f.velocity = -face * 3.0 + Vector3.UP * 3.5
			return true
		if y >= top.y - 0.05:
			end_climb(f, top + Vector3.UP * 0.2)
			f.velocity = face * 1.5
			say_once("climbed", "tip", "Push the stick up to climb, down to go back, JUMP to let go.")
			return true
		if y <= bottom.y + 0.02 and v < -0.1:
			end_climb(f, bottom + Vector3.UP * 0.05)
			return true
		f.global_position = Vector3(bottom.x, maxf(y, bottom.y), bottom.z)
		return true
	if f.state != "idle" or prone or in_cover() or ladders.is_empty():
		return false
	for l: Dictionary in ladders:
		var b: Vector3 = l.bottom
		var p: Vector3 = f.global_position
		if Vector2(p.x - b.x, p.z - b.z).length() < 0.95 and p.y > b.y - 0.6 and p.y < (l.top as Vector3).y - 0.8 \
				and dir.length() > 0.3 and dir.normalized().dot(l.face) > 0.5:
			climb_ladder = l
			climb_mask = f.collision_mask
			f.collision_mask = 0
			f.state = "climb"
			f.state_t = 0.0
			if crouched:
				set_crouch(false)
			sound("step", -10)
			return true
	return false

func end_climb(f: CharacterBody3D, at: Vector3) -> void:
	f.global_position = at
	f.collision_mask = climb_mask
	f.state = "idle"
	f.state_t = 0.0

func section_clear(s: int) -> bool:
	for e: CharacterBody3D in enemies:
		if e.section == s and e.alive():
			return false
	return true

func progress_check() -> void:
	if stage == "village":
		village.progress(get_process_delta_time())
		return
	if stage == "forest":
		forest.progress()
		forest.tick(get_process_delta_time())
		return
	if stage == "citadel":
		ruin.progress()
		return
	if section < 3 and section_clear(section):
		open_barrier(section)
		section += 1
		match section:
			1:
				say("ally", "They're blocking the bridge. We have to break through!")
				say("ally", "Jump the broken gaps. Don't look down!")
			2:
				say("ally", "More enemies ahead. Stay sharp!")
			3:
				say("ally", "The throne hall. He's waiting for us.")
	var z: float = hero.global_position.z
	var reached: int = 0
	if z < -39.5: reached = 1
	if z < -93.5: reached = 2
	if z < -130.0: reached = 3
	if reached > checkpoint and reached <= section:
		checkpoint = reached
	if not boss_seen and z < -136.0:
		boss_seen = true
		boss.active = true
		sound("alarm", -8)
		say("boss", "Still struggling? How crude.")
		say("ally", "We can break through! Keep pressing!")

func say(who: String, text: String) -> void:
	hud.dialogue(who, text)

func say_once(id: String, who: String, text: String) -> void:
	if said.has(id):
		return
	said[id] = true
	say(who, text)

# ---------------------------------------------------------------- effects

func spawn_number(pos: Vector3, amount: float, is_hero: bool) -> void:
	hud.number(pos, str(int(round(amount))), Color("ff6a6a") if is_hero else Color("fff2c4"))

func burst(pos: Vector3, color: Color, count: int, speed: float) -> void:
	if phone:
		count = maxi(6, count / 2)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = spark_texture()
	qm.material = m
	p.mesh = qm
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

var _spark: Texture2D
func spark_texture() -> Texture2D:
	if _spark == null:
		var g: GradientTexture2D = GradientTexture2D.new()
		var gr: Gradient = Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		g.gradient = gr
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 32
		g.height = 32
		_spark = g
	return _spark

func ring(pos: Vector3, radius: float, color: Color, life: float) -> Dictionary:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	mi.mesh = tm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	mi.material_override = m
	mi.scale = Vector3(0.1, 1.0, 0.1)
	add_child(mi)
	mi.global_position = pos
	var fx: Dictionary = {"node": mi, "t": 0.0, "life": life, "radius": radius, "color": color, "center": pos}
	effects.append(fx)
	return fx

func update_effects(dt: float) -> void:
	if paused():
		return
	update_bolts(dt)
	update_throws(dt)
	fx.tick(dt)
	for fx: Dictionary in effects.duplicate():
		fx.t += dt
		var k: float = fx.t / fx.life
		var r: float = lerpf(0.2, fx.radius, k)
		var node: MeshInstance3D = fx.node
		node.scale = Vector3(r, 1.0 + (2.0 if fx.has("damage") else 0.0), r)
		var c: Color = fx.color
		c.a = 1.0 - k
		(node.material_override as StandardMaterial3D).albedo_color = c
		if fx.has("damage") and not fx.hit and hero.alive():
			var d: float = Vector2(hero.global_position.x - fx.center.x, hero.global_position.z - fx.center.z).length()
			var grounded: bool = hero.global_position.y - fx.center.y < 0.55
			if absf(d - r) < 0.9 and grounded and hero.state not in ["dodge", "dashchain"]:
				fx.hit = true
				hero.damage(fx.damage, fx.center, 0.5)
				sound("hurt", -4)
				shake = 0.8
			elif absf(d - r) < 0.9 and not grounded and not fx.has("dodged"):
				fx["dodged"] = true
				hud.popup("DODGED", Color("8fe9ff"))
		if k >= 1.0:
			node.queue_free()
			effects.erase(fx)

# ---------------------------------------------------------------- lock-on, charge, magic

## HUD queries for button state.
## Draw or put away the sword. The blade changes hands halfway through the
## reach so it looks pulled from (or slid onto) the back.
func start_draw(out: bool) -> void:
	draw_target = out
	draw_t = DRAW_TIME
	draw_swapped = false
	sound("hook", -16)

func sword_tick(f: CharacterBody3D, dt: float, toggle: bool, wants_fight: bool) -> void:
	if draw_t > 0.0:
		draw_t = maxf(0.0, draw_t - dt)
		if not draw_swapped and draw_t <= DRAW_TIME * 0.5:
			draw_swapped = true
			sword_out = draw_target
			sound("chip", -10 if sword_out else -14)
		return
	if not f.alive() or f.state not in ["idle", "block"]:
		return
	if toggle:
		start_draw(not sword_out)
		if f.state == "block":
			f.state = "idle"
	elif not sword_out and wants_fight:
		start_draw(true)

## TALK shows only in the village, next to a villager (or while chatting).
func button_visible(id: String) -> bool:
	if id == "talk":
		return stage == "village" and village.active and (village.chat.is_open() or village.chat.nearest() != null)
	return true

func button_ready(id: String) -> bool:
	match id:
		"dodge":
			return stamina >= 18.0
		"magic":
			return mana >= 25.0
		"potion":
			return potions > 0
		"skill":
			return hero != null and hero.state in ["idle", "block"] or charge > 0.0
	return true

func button_fill(id: String) -> float:
	match id:
		"skill":
			return charge
		"magic":
			return mana / 100.0 if mana < 25.0 else 0.0
	return 0.0

func button_badge(id: String) -> String:
	match id:
		"potion":
			return str(potions)
		"skill", "magic":
			return str(marks.size()) if marks.size() > 0 else ""
	return ""

## Tap on an enemy to mark it. Up to three marks; tapping a marked enemy clears it.
func tap_target(ui_pos: Vector2) -> void:
	var best: CharacterBody3D = null
	var best_d: float = 90.0
	for e: CharacterBody3D in enemies:
		if not e.alive() or not e.visible:
			continue
		for h: float in [0.35, 0.65, 0.95]:
			var sp: Vector2 = hud.project(e.global_position + Vector3.UP * e.height * h)
			var d: float = sp.distance_to(ui_pos)
			if d < best_d:
				best_d = d
				best = e
	if best == null:
		return
	if best in marks:
		marks.erase(best)
		sound("bleep", -14)
		return
	marks.append(best)
	while marks.size() > 3:
		marks.pop_front()
	if not best.stealth:
		best.active = true
	sound("bleep", -8)
	say_once("marks", "tip", "Marked! Hold CHARGE and release to dash through marks. MAGIC seeks them too.")

func chain_targets(f: CharacterBody3D) -> Array:
	var list: Array = marks.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.alive())
	if list.is_empty():
		var best: CharacterBody3D = null
		var best_d: float = 9.0
		for e: CharacterBody3D in enemies:
			if not e.alive() or not e.visible:
				continue
			var to: Vector3 = e.global_position - f.global_position
			var d: float = to.length()
			if d < best_d and f.forward().dot(to.normalized()) > 0.2:
				best_d = d
				best = e
		if best:
			list.append(best)
	return list

func start_chain(f: CharacterBody3D, power: float) -> void:
	chain = chain_targets(f)
	chain_power = power
	chain_i = -1
	if chain.is_empty():
		# No target: a straight dash slash ahead.
		chain = [null]
	sound("hook", -8)
	f.set_state("dashchain", CHAIN_SEG * chain.size())
	next_chain_segment(f)

func next_chain_segment(f: CharacterBody3D) -> void:
	chain_i += 1
	f.plunge_t = 0.0
	f.hit_done = false
	f.combo = chain_i % 2
	chain_from = f.global_position
	var t: Variant = chain[chain_i]
	if t == null or not is_instance_valid(t) or not t.alive():
		chain_to = f.global_position + f.forward() * 7.0
	else:
		var tp: Vector3 = (t as CharacterBody3D).global_position
		var away: Vector3 = (chain_from - tp)
		away.y = 0
		var side: Vector3 = Vector3(-away.z, 0, away.x).normalized() * (0.8 if chain_i % 2 == 0 else -0.8)
		chain_to = tp + away.normalized() * (1.5 if t != boss else 2.4) + side
		chain_to.y = maxf(tp.y, chain_from.y)
	ghost(f)

func chain_tick(f: CharacterBody3D, dt: float) -> void:
	f.plunge_t += dt
	var k: float = clampf(f.plunge_t / (CHAIN_SEG * 0.5), 0.0, 1.0)
	var flat_to: Vector3 = chain_to
	f.global_position = chain_from.lerp(flat_to, 1.0 - pow(1.0 - k, 3.0))
	f.velocity = Vector3.ZERO
	var t: Variant = chain[chain_i]
	if t != null and is_instance_valid(t):
		f.face_toward((t as CharacterBody3D).global_position, dt, 30.0)
	f.rig.trail_on = true
	if not f.hit_done and k >= 1.0:
		f.hit_done = true
		var dmg: float = 26.0 + 34.0 * chain_power
		if t != null and is_instance_valid(t) and t.alive():
			var e: CharacterBody3D = t
			wake(e)
			e.damage(dmg, f.global_position, 0.6)
			fx.sword_hit(f, e, Color("ffe08a"), true, chain_i % 3)
			sound("hit", -4)
			shake = 0.6
		else:
			hero_strike(f, dmg, 2.6, 0.2, 0.6)
	if f.plunge_t >= CHAIN_SEG:
		if chain_i + 1 < chain.size():
			next_chain_segment(f)
		else:
			f.rig.trail_on = false
			f.state = "idle"
			burst_window = 1.4
			if chain.size() > 1:
				hud.popup("%d-HIT DASH" % chain.size(), Color("ffe08a"))

func ghost(f: CharacterBody3D) -> void:
	## Brief afterimage at the dash start.
	var g: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.7
	g.mesh = cap
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.5, 0.9, 1.0, 0.45)
	g.material_override = m
	add_child(g)
	g.global_position = f.global_position + Vector3.UP * 0.9
	var tw: Tween = create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(g.queue_free)

func cast_magic(f: CharacterBody3D) -> void:
	if mana < 25.0:
		hud.popup("NO MANA", Color("b48cff"))
		return
	mana -= 25.0
	var targets: Array = marks.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.alive())
	if targets.is_empty():
		var best: CharacterBody3D = null
		var best_d: float = 16.0
		for e: CharacterBody3D in enemies:
			if e.alive() and e.visible and e.global_position.distance_to(f.global_position) < best_d:
				best_d = e.global_position.distance_to(f.global_position)
				best = e
		if best:
			targets.append(best)
	var boosted: bool = burst_window > 0.0
	if boosted:
		hud.popup("MAGIC BURST", Color("b48cff"))
		burst_window = 0.0
	if targets.is_empty():
		targets.append(null)
	for i in targets.size():
		spawn_bolt(f.global_position + Vector3.UP * 1.5 + f.forward() * 0.5, targets[i], boosted, i)
	sound("pulse", -6)

func spawn_bolt(from: Vector3, target: Variant, boosted: bool, i: int) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.22 if not boosted else 0.32
	sm.height = sm.radius * 2.0
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("d9c2ff")
	m.emission_enabled = true
	m.emission = Color("b48cff")
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	add_child(mi)
	mi.global_position = from
	if not phone:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color("b48cff")
		light.light_energy = 1.5
		light.omni_range = 3.0
		mi.add_child(light)
	var side: Vector3 = Vector3(cos(i * 2.1), 0.6, sin(i * 2.1))
	bolts.append({"node": mi, "target": target, "vel": hero.forward() * 6.0 + side * 6.0, "t": 0.0, "dmg": 46.0 if boosted else 26.0})

func update_bolts(dt: float) -> void:
	for b: Dictionary in bolts.duplicate():
		b.t += dt
		var node: MeshInstance3D = b.node
		var pos: Vector3 = node.global_position
		var t: Variant = b.target
		var aim: Vector3
		if t != null and is_instance_valid(t) and t.alive():
			aim = (t as CharacterBody3D).global_position + Vector3.UP * (t as CharacterBody3D).height * 0.55
		else:
			aim = pos + (b.vel as Vector3).normalized() * 3.0
		var want: Vector3 = (aim - pos).normalized() * 17.0
		b.vel = (b.vel as Vector3).lerp(want, 1.0 - exp(-5.0 * dt))
		node.global_position = pos + (b.vel as Vector3) * dt
		if t != null and is_instance_valid(t) and t.alive() and node.global_position.distance_to(aim) < 0.7:
			var e: CharacterBody3D = t
			wake(e)
			e.damage(b.dmg, node.global_position, 0.35)
			fx.impact(node.global_position, Color("b48cff"), 1.4)
			fx.sparks(node.global_position, Color("d9c2ff"), 18, 6.0)
			fx.count_hit()
			sound("hit", -8)
			node.queue_free()
			bolts.erase(b)
		elif b.t > 2.5:
			burst(node.global_position, Color("d9c2ff"), 8, 2.0)
			node.queue_free()
			bolts.erase(b)

# ---------------------------------------------------------------- stealth (ported from the MG build)

func in_cover() -> bool:
	return not cover.is_empty()

func hero_target_point() -> Vector3:
	## Same idea as Player.target_point(): lower when crouched or crawling.
	return hero.global_position + Vector3.UP * (0.35 if prone else (0.6 if crouched else 0.95))

func set_hero_shape(h: float) -> void:
	var cs: CollisionShape3D = hero.get_child(0)
	var cap: CapsuleShape3D = cs.shape
	cap.height = h
	cap.radius = minf(0.38, h * 0.5)
	cs.position.y = h * 0.5

func can_stand() -> bool:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, hero.global_position + Vector3.UP * 0.9)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func set_crouch(on: bool) -> void:
	if not on and not can_stand():
		hud.popup("TOO LOW TO STAND", Color("ffb03b"))
		return
	crouched = on
	prone = false
	set_hero_shape(1.2 if on else 1.8)

func set_crawl(on: bool) -> void:
	if not on and not can_stand():
		hud.popup("TOO LOW TO STAND", Color("ffb03b"))
		return
	if in_cover():
		toggle_cover()
	prone = on
	crouched = false
	cover_cooldown = 0.5
	set_hero_shape(0.6 if on else 1.8)
	sound("cover", -14)

func leave_stance() -> void:
	if in_cover():
		toggle_cover()
	if prone:
		set_crawl(false)

## Old Player.toggle_cover(): snap to the nearest wall face within reach.
func toggle_cover() -> void:
	if in_cover():
		cover.clear()
		cover_cooldown = 0.7
		peeking = false
		peek_dir = Vector3.ZERO
		if cover_low and crouched:
			set_crouch(false)
		cover_low = false
		return
	if prone or not hero.is_on_floor():
		return
	var p: Vector2 = Vector2(hero.global_position.x, hero.global_position.z)
	var found: Dictionary = Spatial.cover_face(p, walls, 1.3)
	if found.is_empty():
		hud.popup("MOVE CLOSER TO A WALL", Color("ffb03b"))
		return
	cover = found
	hero.global_position = Vector3(found.point.x, hero.global_position.y, found.point.y)
	hero.velocity = Vector3.ZERO
	var n: Vector2 = found.normal
	hero.yaw = atan2(-n.x, -n.y)
	cover_low = float(wall_heights.get(found.wall, 3.0)) < 1.4
	if cover_low:
		set_crouch(true)
	sound("cover")
	say_once("cover", "tip", "Slide along the wall. Hold PEEK at the edge. DISTRACT knocks to lure guards.")

## Old Player.tick() cover branch: slide along the face, stop and peek at the edge.
func cover_move(f: CharacterBody3D, dt: float, mv: Vector2, dir: Vector3) -> void:
	var n: Vector2 = cover.normal
	var tangent: Vector2 = Vector2(-n.y, n.x)
	var move: Vector2 = Vector2(dir.x, dir.z)
	peek_dir = Vector3.ZERO
	if move.dot(n) > 0.7:
		toggle_cover()
		return
	var along: float = move.dot(tangent)
	var direction: Vector3 = Vector3(tangent.x, 0, tangent.y) * along
	var speed: float = 1.8
	var rect: Rect2 = cover.wall
	var axis: int = 1 if absf(n.x) > 0.5 else 0
	var pt: Vector2 = Vector2(f.global_position.x, f.global_position.z)
	var proposed: float = pt[axis] + Vector2(direction.x, direction.z)[axis] * speed * dt
	if absf(along) > 0.1:
		cover_side = signf(along)
	if proposed < rect.position[axis] + 0.15 or proposed > rect.end[axis] - 0.15:
		peek_dir = direction.normalized()
		direction = Vector3.ZERO
	if peeking:
		peek_dir = Vector3(tangent.x, 0, tangent.y) * cover_side
	f.velocity.x = direction.x * speed
	f.velocity.z = direction.z * speed
	cover_motion = f.velocity
	f.yaw = lerp_angle(f.yaw, atan2(-n.x, -n.y), 1.0 - exp(-12.0 * dt))

## Old wall-pressure rule: pushing into a wall for 0.22 s takes cover.
## Only outside a fight, so it never grabs you mid-combat.
func auto_cover(f: CharacterBody3D, dt: float, dir: Vector3) -> void:
	cover_cooldown = maxf(0.0, cover_cooldown - dt)
	if not prone and f.is_on_wall() and dir.length() > 0.3 and cover_cooldown <= 0 and f.is_on_floor() and not fighting():
		wall_pressure += dt
		if wall_pressure > 0.22:
			toggle_cover()
			wall_pressure = 0.0
	else:
		wall_pressure = 0.0

func fighting() -> bool:
	for e: CharacterBody3D in enemies:
		if e.alive() and e.active and e.global_position.distance_to(hero.global_position) < 12.0:
			return true
	return false

## Old footstep noise: walking upright is heard nearby; crouching and crawling are silent.
func footsteps(f: CharacterBody3D, dt: float) -> void:
	foot_time -= dt
	var hs: float = Vector2(f.velocity.x, f.velocity.z).length()
	if hs > 2.6 and f.is_on_floor() and foot_time <= 0 and not crouched and not prone:
		foot_time = 0.42
		noise(f.global_position, 4.5)

func noise(at: Vector3, radius: float) -> void:
	for e: CharacterBody3D in enemies:
		if e.stealth and e.global_position.distance_to(at) < radius:
			patrol.hear(e, at)

func stealth_input(f: CharacterBody3D, dt: float) -> void:
	distract_cd -= dt
	if mode != "play" or not f.alive():
		peeking = false
		return
	var free: bool = f.state in ["idle", "block"]
	# CROUCH: tap toggles crouch; hold for crawl (the MG build's crawl).
	var crouch_down: bool = hud.held("crouch") or Input.is_action_pressed("cc_crouch")
	if hud.take("crouch") or Input.is_action_just_pressed("cc_crouch"):
		crouch_hold = 0.0
		crouch_long = false
	if crouch_down:
		crouch_hold += dt
		if crouch_hold > 0.45 and not crouch_long and free:
			crouch_long = true
			set_crawl(not prone)
	if (hud.took_release("crouch") or Input.is_action_just_released("cc_crouch")) and not crouch_long and free:
		if prone:
			set_crawl(false)
		elif not (in_cover() and cover_low):
			set_crouch(not crouched)
			sound("cover", -16)
	if Input.is_action_just_pressed("cc_crawl") and free:
		set_crawl(not prone)
	if (hud.take("hug") or Input.is_action_just_pressed("cc_hug")) and free:
		toggle_cover()
	var want_peek: bool = hud.held("peek") or Input.is_action_pressed("cc_peek")
	if want_peek and not in_cover():
		if hud.take("peek"):
			hud.popup("WALL HUG FIRST", Color("ffb03b"))
		want_peek = false
	hud.take("peek")
	peeking = want_peek
	if (hud.take("distract") or Input.is_action_just_pressed("cc_distract")) and distract_cd <= 0:
		distract_cd = 1.2
		if in_cover():
			# Old "knock": guards within 11 m come to investigate.
			noise(f.global_position, 11.0)
			sound("knock")
			hud.popup("KNOCK", Color("ffcf6a"))
		else:
			throw_pebble(f)

func throw_pebble(f: CharacterBody3D) -> void:
	var from: Vector3 = f.global_position + Vector3.UP * 1.5
	var to: Vector3 = f.global_position + f.forward() * 8.0
	var hit: Dictionary = ray(from, to + Vector3.UP * 1.0)
	if not hit.is_empty():
		to = hit.position - f.forward() * 0.3
	var ground: Dictionary = ray(to + Vector3.UP * 2.0, to + Vector3.DOWN * 4.0)
	if not ground.is_empty():
		to = ground.position
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	mi.mesh = sm
	mi.material_override = mat("gold")
	add_child(mi)
	mi.global_position = from
	throws.append({"node": mi, "from": from, "to": to, "t": 0.0})
	sound("step", -10)

func update_throws(dt: float) -> void:
	for t: Dictionary in throws.duplicate():
		t.t += dt
		var k: float = clampf(t.t / 0.6, 0, 1)
		var pos: Vector3 = (t.from as Vector3).lerp(t.to, k) + Vector3.UP * sin(k * PI) * 2.0
		(t.node as Node3D).global_position = pos
		if k >= 1.0:
			noise(t.to, 9.0)
			sound("knock", -6)
			ring(t.to + Vector3.UP * 0.05, 1.2, Color("ffcf6a"), 0.5)
			(t.node as Node3D).queue_free()
			throws.erase(t)

func wake(e: CharacterBody3D) -> void:
	if e.stealth and not e.active:
		alert_guard(e)
	e.active = true

func alert_guard(e: CharacterBody3D) -> void:
	if e.active or not e.alive():
		return
	e.active = true
	e.gstate = "CHASE"
	e.attack_cd = 0.8
	if e.cone:
		e.cone.visible = false
	sound("alarm", -10)
	if stage == "forest":
		forest.on_alarm(e)
	hud.number(e.global_position + Vector3.UP * (e.height + 0.5), "!", Color("ff3346"))
	say_once("spotted", "ally", "They've spotted us! Fight or break line of sight!")

func stealth_status() -> String:
	## "" when no patrol guards are around; otherwise HIDDEN / SUSPICIOUS / ALERT.
	var any: bool = false
	var sus: bool = false
	for e: CharacterBody3D in enemies:
		if not e.stealth or not e.alive():
			continue
		any = true
		if e.active:
			return "ALERT"
		if e.suspicion > 0.05 or e.gstate in ["INVESTIGATE", "SEARCH"]:
			sus = true
	if not any:
		return ""
	return "SUSPICIOUS" if sus else "HIDDEN"

func stealth_on(id: String) -> bool:
	match id:
		"crouch":
			return crouched or prone
		"hug":
			return in_cover()
		"peek":
			return peeking
	return false

func hero_low() -> bool:
	return crouched or prone or (in_cover() and cover_low)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if village and village.active:
			village.save_now()
