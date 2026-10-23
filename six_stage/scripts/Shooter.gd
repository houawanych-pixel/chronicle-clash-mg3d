extends RefCounted
## First-person shooter mode (Call of Duty-style), layered on the stealth game.
## VIEW (1ST/3RD button, O key) switches between the third-person stealth camera
## and a first-person camera at eye height. In first person you move and look at
## the same time, hip-fire without aiming, and AIM becomes aim-down-sights (tighter
## spread, zoom, slower walk). Every gun kicks (recoil that recovers), shows a
## first-person weapon model, and hits show a hit marker; head shots do triple damage.

const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.1
const EYE_PRONE: float = 0.42
const HEAD_LINE: float = 1.42       # hits above this height on a guard are head shots
const HEAD_MULT: float = 3.0
const RECOVER: float = 2.6          # recoil pitch recovered per second (radians)

## Per-weapon feel: hip spread / ADS spread (degrees), recoil kick (radians), ADS FOV.
const FEEL: Dictionary = {
	"pistol": {"hip": 2.2, "ads": 0.35, "kick": 0.035, "fov": 46.0},
	"rifle": {"hip": 3.2, "ads": 0.6, "kick": 0.022, "fov": 42.0},
	"smg": {"hip": 2.8, "ads": 0.9, "kick": 0.016, "fov": 48.0},
	"sniper": {"hip": 7.0, "ads": 0.05, "kick": 0.09, "fov": 18.0},
	"rocket": {"hip": 1.5, "ads": 0.5, "kick": 0.06, "fov": 44.0},
}
const HIP_FOV: float = 66.0

var game: Node
var on: bool = false
var ads: bool = false
var ads_blend: float = 0.0
var recoil: float = 0.0             # pitch still to recover
var bloom: float = 0.0              # extra spread from firing quickly (0..1)
var hit_time: float = 0.0
var hit_kill: bool = false
var hit_head: bool = false
var head_text_time: float = 0.0
var bob: float = 0.0
var kick_back: float = 0.0
var viewmodel: Node3D
var guns: Dictionary = {}
var flash: MeshInstance3D
var since_shot: float = 9.0
var stats: Dictionary = {"shots": 0, "hits": 0, "heads": 0, "kills": 0}

func _init(g: Node) -> void:
	game = g

func reset() -> void:
	ads = false
	ads_blend = 0.0
	recoil = 0.0
	bloom = 0.0
	hit_time = 0.0

func feel() -> Dictionary:
	return FEEL.get(str(game.gear.current().id), FEEL.pistol)

## Can first person be used right now (not while climbing, hanging, on a rope...)?
func active() -> bool:
	return on and is_instance_valid(game.player) and game.player.mode in ["ground", "swim"]

func toggle() -> void:
	set_on(not on)

func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	ads = false
	var p: CharacterBody3D = game.player
	if on:
		if game.lab.aim:
			game.set_precision(false)
		if p.mode == "cover":
			p.toggle_cover()
		var f: Vector3 = p.facing
		game.lab.yaw = atan2(-f.x, -f.z)
		game.lab.pitch = 0.0
		game.toast("FIRST PERSON: right side looks. ADS = sights.")
		if mouse_ok():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		game.toast("Third person.")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.sound("cover", -14)
	if is_instance_valid(viewmodel):
		viewmodel.visible = false

## Desktop with a mouse: capture it for mouse-look (Esc pauses and frees it).
func mouse_ok() -> bool:
	return DisplayServer.get_name() != "headless" and not DisplayServer.is_touchscreen_available()

func toggle_ads() -> void:
	if not active():
		return
	ads = not ads
	game.sound("cover", -18)

func set_ads(value: bool) -> void:
	if active():
		ads = value

func eye() -> Vector3:
	var p: CharacterBody3D = game.player
	var h: float = EYE_PRONE if p.prone else (EYE_CROUCH if p.crouched else EYE_STAND)
	return p.global_position + Vector3.UP * h

func look_dir() -> Vector3:
	return game.lab.look_direction()

func flat_dir() -> Vector3:
	var d: Vector3 = look_dir()
	d.y = 0
	return d.normalized() if d.length() > 0.01 else game.player.facing

func fov() -> float:
	return lerpf(HIP_FOV, float(feel().fov), ads_blend)

func spread_deg() -> float:
	var f: Dictionary = feel()
	var base: float = lerpf(float(f.hip), float(f.ads), ads_blend)
	var moving: float = clampf(Vector2(game.player.velocity.x, game.player.velocity.z).length() / 4.4, 0.0, 1.0)
	return base * (1.0 + bloom * 1.5 + moving * (0.8 if ads_blend < 0.5 else 0.25))

## Bend a shot direction by the current spread.
func spread(direction: Vector3) -> Vector3:
	var deg: float = spread_deg()
	if deg <= 0.001:
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up: Vector3 = side.cross(direction).normalized()
	var a: float = randf() * TAU
	var r: float = deg_to_rad(deg) * sqrt(randf())
	return (direction + side * cos(a) * tan(r) + up * sin(a) * tan(r)).normalized()

## Called by Equipment.fire after a gun shot.
func kicked() -> void:
	stats.shots += 1
	if not active():
		return
	var k: float = float(feel().kick) * (0.55 if ads_blend > 0.5 else 1.0)
	recoil += k
	game.lab.pitch = clampf(game.lab.pitch + k, -1.3, 1.3)
	game.lab.yaw += randf_range(-k, k) * 0.45
	bloom = minf(1.0, bloom + 0.22)
	kick_back = 1.0
	since_shot = 0.0

## Hit marker / head shot bookkeeping (both views).
func register_hit(target: Object, at: Vector3, damage: float, head: bool) -> void:
	stats.hits += 1
	hit_time = 0.22
	hit_head = head
	var dead: bool = target.get("health") != null and float(target.health) <= 0.0
	hit_kill = dead
	if head:
		stats.heads += 1
		head_text_time = 1.0
	if dead:
		stats.kills += 1
	game.sound("hit", -6 if head else -11)

## Damage multiplier for a hit on a guard at a world point.
func head_shot(target: Object, at: Vector3) -> bool:
	if not (target in game.guards):
		return false
	return at.y - (target as Node3D).global_position.y > HEAD_LINE

func tick(delta: float) -> void:
	hit_time = maxf(0.0, hit_time - delta)
	head_text_time = maxf(0.0, head_text_time - delta)
	since_shot += delta
	if since_shot > 0.2:
		bloom = maxf(0.0, bloom - delta * 1.8)
	kick_back = maxf(0.0, kick_back - delta * 9.0)
	ads_blend = move_toward(ads_blend, 1.0 if (ads and active()) else 0.0, delta * 6.0)
	if recoil > 0.0 and since_shot > 0.15:
		var back: float = minf(recoil, RECOVER * delta * (0.4 + recoil * 8.0))
		recoil -= back
		game.lab.pitch = clampf(game.lab.pitch - back, -1.3, 1.3)
	if active():
		var sp: float = Vector2(game.player.velocity.x, game.player.velocity.z).length()
		bob += delta * sp * 2.2
		game.player.facing = flat_dir()
	update_viewmodel(delta)

# ---------------------------------------------------------------- first-person weapon

func build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	game.camera.add_child(viewmodel)
	var steel: StandardMaterial3D = mat(Color("2b3038"), 0.7, 0.35)
	var dark: StandardMaterial3D = mat(Color("15181d"), 0.3, 0.6)
	var tan: StandardMaterial3D = mat(Color("6d5a3e"), 0.1, 0.8)
	var glass: StandardMaterial3D = mat(Color("3fd2ff"), 0.2, 0.1)
	glass.emission_enabled = true
	glass.emission = Color("1d8fb0")
	# Side profiles (x = forward along the barrel, y = up), extruded to the gun's width.
	guns["pistol"] = gun([
		[[Vector2(-0.06, 0.02), Vector2(0.15, 0.02), Vector2(0.15, 0.07), Vector2(-0.07, 0.07), Vector2(-0.08, 0.05)], 0.032, steel],
		[[Vector2(-0.06, 0.02), Vector2(-0.01, 0.02), Vector2(-0.03, -0.1), Vector2(-0.09, -0.1), Vector2(-0.08, 0.0)], 0.034, dark],
		[[Vector2(0.0, 0.02), Vector2(0.05, 0.02), Vector2(0.04, -0.02), Vector2(0.0, -0.02)], 0.012, dark],
	])
	guns["rifle"] = gun([
		[[Vector2(-0.12, 0.0), Vector2(0.32, 0.0), Vector2(0.32, 0.06), Vector2(-0.12, 0.06)], 0.05, steel],
		[[Vector2(0.32, 0.02), Vector2(0.62, 0.02), Vector2(0.62, 0.045), Vector2(0.32, 0.045)], 0.022, dark],
		[[Vector2(0.1, 0.0), Vector2(0.17, 0.0), Vector2(0.2, -0.17), Vector2(0.13, -0.18)], 0.04, dark],
		[[Vector2(-0.06, 0.0), Vector2(-0.01, 0.0), Vector2(-0.04, -0.11), Vector2(-0.1, -0.11)], 0.045, dark],
		[[Vector2(-0.12, 0.05), Vector2(-0.12, -0.02), Vector2(-0.36, -0.06), Vector2(-0.36, 0.05)], 0.045, tan],
		[[Vector2(0.0, 0.06), Vector2(0.18, 0.06), Vector2(0.18, 0.1), Vector2(0.0, 0.1)], 0.03, dark],
	])
	guns["smg"] = gun([
		[[Vector2(-0.08, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.065), Vector2(-0.08, 0.065)], 0.05, steel],
		[[Vector2(0.24, 0.02), Vector2(0.38, 0.02), Vector2(0.38, 0.05), Vector2(0.24, 0.05)], 0.03, dark],
		[[Vector2(0.06, 0.0), Vector2(0.11, 0.0), Vector2(0.12, -0.2), Vector2(0.07, -0.2)], 0.035, dark],
		[[Vector2(-0.05, 0.0), Vector2(0.0, 0.0), Vector2(-0.03, -0.1), Vector2(-0.08, -0.1)], 0.045, dark],
		[[Vector2(-0.08, 0.05), Vector2(-0.24, 0.04), Vector2(-0.24, 0.0), Vector2(-0.08, 0.01)], 0.02, steel],
	])
	guns["sniper"] = gun([
		[[Vector2(-0.1, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.055), Vector2(-0.1, 0.055)], 0.05, steel],
		[[Vector2(0.3, 0.018), Vector2(0.85, 0.018), Vector2(0.85, 0.04), Vector2(0.3, 0.04)], 0.02, dark],
		[[Vector2(-0.04, 0.0), Vector2(0.01, 0.0), Vector2(-0.02, -0.11), Vector2(-0.08, -0.11)], 0.045, dark],
		[[Vector2(-0.1, 0.05), Vector2(-0.1, -0.03), Vector2(-0.42, -0.07), Vector2(-0.42, 0.05)], 0.05, tan],
		[[Vector2(-0.04, 0.07), Vector2(0.24, 0.07), Vector2(0.26, 0.12), Vector2(-0.06, 0.12)], 0.045, dark],
		[[Vector2(0.255, 0.075), Vector2(0.265, 0.075), Vector2(0.265, 0.115), Vector2(0.255, 0.115)], 0.05, glass],
	])
	guns["rocket"] = gun([
		[[Vector2(-0.35, -0.05), Vector2(0.45, -0.05), Vector2(0.45, 0.09), Vector2(-0.35, 0.09)], 0.13, mat(Color("4e5b3a"), 0.2, 0.7)],
		[[Vector2(0.0, -0.05), Vector2(0.05, -0.05), Vector2(0.03, -0.17), Vector2(-0.02, -0.17)], 0.04, dark],
		[[Vector2(0.1, 0.09), Vector2(0.2, 0.09), Vector2(0.2, 0.14), Vector2(0.1, 0.14)], 0.04, dark],
	])
	flash = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	flash.mesh = q
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.45, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash.material_override = fm
	flash.visible = false
	viewmodel.add_child(flash)

static func mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## parts: [[outline points, width, material], ...]; the gun points down -Z (camera forward).
func gun(parts: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	root.visible = false
	viewmodel.add_child(root)
	for part: Array in parts:
		var pts: PackedVector2Array = PackedVector2Array(part[0])
		root.add_child(extrude(pts, float(part[1]), part[2]))
	return root

static func extrude(outline: PackedVector2Array, width: float, m: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if tris.is_empty():
		tris = Geometry2D.triangulate_polygon(PackedVector2Array(Array(outline).duplicate()))
	var l: Array = []
	var r: Array = []
	for v: Vector2 in outline:
		# profile x runs forward (-Z), y up; width along X
		l.append(Vector3(-width * 0.5, v.y, -v.x))
		r.append(Vector3(width * 0.5, v.y, -v.x))
	for i in range(0, tris.size(), 3):
		st.add_vertex(l[tris[i]])
		st.add_vertex(l[tris[i + 1]])
		st.add_vertex(l[tris[i + 2]])
		st.add_vertex(r[tris[i]])
		st.add_vertex(r[tris[i + 2]])
		st.add_vertex(r[tris[i + 1]])
	var n: int = outline.size()
	for i in n:
		var j: int = (i + 1) % n
		st.add_vertex(l[i])
		st.add_vertex(r[i])
		st.add_vertex(l[j])
		st.add_vertex(l[j])
		st.add_vertex(r[i])
		st.add_vertex(r[j])
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func current_gun() -> String:
	var id: String = str(game.gear.current().id)
	return id if guns.has(id) else ""

func update_viewmodel(delta: float) -> void:
	var show: bool = active() and game.lab.drawn and game.camera_controller.view == "fps"
	if not show:
		if is_instance_valid(viewmodel):
			viewmodel.visible = false
		return
	if not is_instance_valid(viewmodel):
		build_viewmodel()
	viewmodel.visible = true
	var id: String = current_gun()
	for k: String in guns:
		(guns[k] as Node3D).visible = k == id
	# sniper scope view hides the gun
	if id == "sniper" and ads_blend > 0.85:
		(guns[id] as Node3D).visible = false
	var hip: Vector3 = Vector3(0.15, -0.15, -0.36)
	var sight: Vector3 = Vector3(0.0, -0.072 if id != "rocket" else -0.095, -0.3)
	var pos: Vector3 = hip.lerp(sight, ads_blend)
	var sway: float = (1.0 - ads_blend * 0.85)
	pos += Vector3(sin(bob) * 0.012, absf(cos(bob)) * 0.01, 0) * sway
	pos.z += kick_back * 0.05
	var rot: Vector3 = Vector3(kick_back * 0.12, 0, 0)
	var g: Node = game.gear
	if g.action_time > 0.0 and g.action_total > 0.0:
		var u: float = 1.0 - g.action_time / g.action_total
		var dip: float = sin(u * PI)
		pos.y -= dip * 0.12
		rot.x -= dip * 0.6
		rot.z += dip * 0.5
	if g.switch_time > 0.0:
		pos.y -= g.switch_time * 0.6
	viewmodel.position = pos
	viewmodel.rotation = rot
	viewmodel.scale = Vector3.ONE * 0.55
	if id != "":
		var muzzle: float = 0.62 if id == "rifle" else (0.85 if id == "sniper" else (0.38 if id == "smg" else (0.45 if id == "rocket" else 0.15)))
		flash.position = Vector3(0, 0.035, -muzzle)
		flash.visible = g.muzzle_time > 0.06
