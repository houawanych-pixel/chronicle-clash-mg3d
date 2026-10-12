extends Node3D
## Procedural animation for the owner's Tripo-rigged GLBs (78-bone skeleton,
## A-pose, facing +X in model space). Poses are written as absolute bone
## directions in model space: F = +X forward, U = +Y up, R = +Z character right.
## A sword is placed at the right hand each frame from the pose's blade direction.

const AIM_PAIRS: Dictionary = {
	"L_Upperarm": "L_Forearm", "L_Forearm": "L_Hand",
	"R_Upperarm": "R_Forearm", "R_Forearm": "R_Hand",
	"L_Thigh": "L_Calf", "L_Calf": "L_Foot",
	"R_Thigh": "R_Calf", "R_Calf": "R_Foot",
}
const ORDER: Array = ["Hip", "Waist", "Spine01", "Spine02", "Head",
	"L_Upperarm", "L_Forearm", "R_Upperarm", "R_Forearm",
	"L_Thigh", "L_Calf", "R_Thigh", "R_Calf"]
const TURN_BONES: Array = ["Hip", "Waist", "Spine01", "Spine02", "Head"]

var model: Node3D
var sk: Skeleton3D
var idx: Dictionary = {}
var rest_q: Dictionary = {}
var parent_q: Dictionary = {}
var rest_dir: Dictionary = {}
var cur: Dictionary = {}
var turn: Dictionary = {}
var to_rig: Transform3D
var ready_xform: bool = false
var sword: Node3D
var blade: MeshInstance3D
var blade_mat: StandardMaterial3D
var blade_len: float = 1.05
var blade_color: Color = Color("8fe9ff")
var glow: float = 0.0
var tip_history: Array = []
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_on: bool = false
var trail_mat: StandardMaterial3D
var height: float = 1.8
var mats: Array = []

func setup(path: String, h: float, color: Color, length: float, glow_base: float) -> void:
	height = h
	blade_color = color
	blade_len = length
	model = (load(path) as PackedScene).instantiate()
	add_child(model)
	model.rotation.y = PI / 2.0
	model.scale = Vector3.ONE * (h / 0.98)
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	for i in sk.get_bone_count():
		idx[sk.get_bone_name(i)] = i
	for i in sk.get_bone_count():
		rest_q[i] = sk.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		var p: int = sk.get_bone_parent(i)
		parent_q[i] = sk.get_bone_global_rest(p).basis.orthonormalized().get_rotation_quaternion() if p >= 0 else Quaternion()
	for a: String in AIM_PAIRS:
		var b: String = AIM_PAIRS[a]
		var d: Vector3 = sk.get_bone_global_rest(idx[b]).origin - sk.get_bone_global_rest(idx[a]).origin
		rest_dir[a] = d.normalized()
		cur[a] = d.normalized()
	for t: String in TURN_BONES:
		turn[t] = Quaternion()
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mats.append(m)
	build_sword(glow_base)
	build_trail()

func build_sword(glow_base: float) -> void:
	sword = Node3D.new()
	add_child(sword)
	blade = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.095, blade_len, 0.025)
	blade.mesh = bm
	blade.position = Vector3(0, blade_len * 0.5 + 0.13, 0)
	blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = blade_color.lerp(Color.WHITE, 0.55)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.15
	blade_mat.emission_enabled = true
	blade_mat.emission = blade_color
	blade_mat.emission_energy_multiplier = glow_base
	blade.material_override = blade_mat
	sword.add_child(blade)
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color("d8b45a")
	gold.metallic = 0.85
	gold.roughness = 0.3
	var guard: MeshInstance3D = MeshInstance3D.new()
	var gm: BoxMesh = BoxMesh.new()
	gm.size = Vector3(0.28, 0.05, 0.06)
	guard.mesh = gm
	guard.position = Vector3(0, 0.11, 0)
	guard.material_override = gold
	sword.add_child(guard)
	var grip: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 0.2
	grip.mesh = cm
	grip.position = Vector3(0, 0.0, 0)
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color("2a2230")
	grip.material_override = dark
	sword.add_child(grip)

func build_trail() -> void:
	trail_mesh = ImmediateMesh.new()
	trail = MeshInstance3D.new()
	trail.mesh = trail_mesh
	trail.top_level = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail_mat = StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_mat.vertex_color_use_as_albedo = true
	trail.material_override = trail_mat
	add_child(trail)

static func d(f: float, u: float, r: float) -> Vector3:
	return Vector3(f, u, r).normalized()

static func sag(angle: float, side: float) -> Vector3:
	## Direction in the forward/up plane: 0 = straight down, + swings forward.
	return Vector3(sin(angle), -cos(angle), side).normalized()

func acc_of(acc: Dictionary, i: int) -> Quaternion:
	var j: int = i
	while j >= 0 and not acc.has(j):
		j = sk.get_bone_parent(j)
	return acc.get(j, Quaternion())

func apply(pose: Dictionary, dt: float, rate: float = 14.0) -> void:
	var k: float = 1.0 - exp(-rate * dt)
	for a: String in AIM_PAIRS:
		if pose.has(a):
			var target: Vector3 = pose[a]
			cur[a] = (cur[a] as Vector3).slerp(target, k).normalized()
	for t: String in TURN_BONES:
		var q: Quaternion = pose.get(t, Quaternion())
		turn[t] = (turn[t] as Quaternion).slerp(q, k)
	var acc: Dictionary = {}
	for name: String in ORDER:
		if not idx.has(name):
			continue
		var i: int = idx[name]
		var accp: Quaternion = acc_of(acc, sk.get_bone_parent(i))
		var r: Quaternion
		if rest_dir.has(name):
			var want: Vector3 = accp.inverse() * (cur[name] as Vector3)
			r = Quaternion(rest_dir[name], want.normalized())
		else:
			r = turn[name]
		acc[i] = accp * r
		var pq: Quaternion = parent_q[i]
		sk.set_bone_pose_rotation(i, (pq.inverse() * r * pq * (rest_q[i] as Quaternion)).normalized())
	place_sword(pose.get("blade", d(1, 0.4, 0)))

func place_sword(blade_dir: Vector3) -> void:
	if not ready_xform and is_inside_tree():
		to_rig = global_transform.affine_inverse() * sk.global_transform
		ready_xform = true
	var hand: Transform3D = sk.get_bone_global_pose(idx["R_Hand"])
	var fore: Transform3D = sk.get_bone_global_pose(idx["R_Forearm"])
	var hand_rig: Vector3 = to_rig * hand.origin
	var arm: Vector3 = (to_rig.basis * (hand.origin - fore.origin)).normalized()
	var up: Vector3 = (to_rig.basis * blade_dir).normalized()
	if up.length() < 0.5:
		up = Vector3.UP
	var side: Vector3 = up.cross(arm)
	if side.length() < 0.05:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	var back: Vector3 = side.cross(up).normalized()
	sword.transform = Transform3D(Basis(side, up, back), hand_rig + arm * 0.05)
	blade_mat.emission_energy_multiplier = 0.6 + glow * 3.0

func tip_world() -> Vector3:
	return sword.global_transform * Vector3(0, blade_len + 0.13, 0)

func base_world() -> Vector3:
	return sword.global_transform * Vector3(0, 0.3, 0)

func update_trail() -> void:
	tip_history.push_front([base_world(), tip_world()])
	while tip_history.size() > 12:
		tip_history.pop_back()
	trail_mesh.clear_surfaces()
	if not trail_on or tip_history.size() < 3:
		return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = tip_history.size()
	for i in n:
		var a: float = 1.0 - float(i) / float(n)
		var tip: Vector3 = tip_history[i][1]
		var base: Vector3 = tip_history[i][0]
		var c: Color = blade_color.lerp(Color.WHITE, 0.6 * a)
		c.a = a
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(tip + (tip - base) * 0.25)
		c = blade_color
		c.a = 0.0
		trail_mesh.surface_set_color(c)
		trail_mesh.surface_add_vertex(base.lerp(tip, 0.15))
	trail_mesh.surface_end()

func set_flash(amount: float, color: Color) -> void:
	## Tints the whole character, used for hit flashes and enemy wind-ups.
	for m: MeshInstance3D in mats:
		if amount <= 0.01:
			m.material_overlay = null
		else:
			var o: StandardMaterial3D = m.material_overlay as StandardMaterial3D
			if o == null:
				o = StandardMaterial3D.new()
				o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				o.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.material_overlay = o
			o.albedo_color = Color(color.r, color.g, color.b, amount)
