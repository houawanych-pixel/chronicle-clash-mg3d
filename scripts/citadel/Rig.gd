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
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if phone_mode() else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	place_shield(dt)

## When true the sword rides on the back (hilt over the right shoulder)
## instead of in the hand.
var sheathed: bool = false

func place_on_back() -> void:
	# Rig space: forward is -Z. Shoulders and hips come from the bones so the
	# sword follows crouching, leaning and different body sizes.
	var rs: Vector3 = to_rig * sk.get_bone_global_pose(idx["R_Upperarm"]).origin
	var ls: Vector3 = to_rig * sk.get_bone_global_pose(idx["L_Upperarm"]).origin
	var lh: Vector3 = to_rig * sk.get_bone_global_pose(idx["L_Thigh"]).origin
	var fwd: Vector3 = Vector3(0, 0, -1)
	var k: float = height / 1.8
	var back_off: Vector3 = -fwd * 0.17 * k
	# Scaled down a little on the back so a long blade ends at the hip
	# instead of dragging on the ground; the hilt rises over the shoulder.
	var sc: float = clampf(0.95 * k / (blade_len + 0.13), 0.55, 1.0)
	var aim_from: Vector3 = rs.lerp(ls, 0.18) + back_off
	var tip: Vector3 = lh.lerp(ls, 0.12) + (ls - rs) * 0.1 + back_off
	var blade_up: Vector3 = (tip - aim_from).normalized()
	var origin: Vector3 = tip - blade_up * (blade_len + 0.13) * sc
	var side: Vector3 = blade_up.cross(fwd).normalized()
	var back: Vector3 = side.cross(blade_up).normalized()
	sword.transform = Transform3D(Basis(side, blade_up, back).scaled(Vector3.ONE * sc), origin)
	blade_mat.emission_energy_multiplier = 0.25

func place_sword(blade_dir: Vector3) -> void:
	if not ready_xform and is_inside_tree():
		to_rig = global_transform.affine_inverse() * sk.global_transform
		ready_xform = true
	if sheathed:
		place_on_back()
		return
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

func phone_mode() -> bool:
	var g: Node = get_parent().get("game") if get_parent() else null
	return g != null and g.get("phone") == true

## Village tools. "sword" keeps the normal blade; anything else hides the blade
## and holds a simple tool along the same direction ("blade" in the pose).
var tool_kind: String = "sword"
var tool_node: Node3D

func set_tool(kind: String) -> void:
	if kind == tool_kind:
		return
	tool_kind = kind
	if tool_node:
		tool_node.queue_free()
		tool_node = null
	for c: Node in sword.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = kind == "sword"
	if kind == "sword" or kind == "none":
		return
	tool_node = Node3D.new()
	sword.add_child(tool_node)
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color("7a5532")
	wood.roughness = 0.9
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = Color("9aa3ad")
	iron.metallic = 0.7
	iron.roughness = 0.4
	var handle_len: float = 2.3 if kind == "rod" else 0.95
	_tool_box(Vector3(0, handle_len * 0.5 - 0.15, 0), Vector3(0.045, handle_len, 0.045), wood)
	match kind:
		"axe":
			_tool_box(Vector3(0.09, 0.72, 0), Vector3(0.2, 0.16, 0.035), iron)
		"pick":
			_tool_box(Vector3(0, 0.76, 0), Vector3(0.5, 0.06, 0.05), iron)
		"hoe":
			_tool_box(Vector3(0.08, 0.78, 0), Vector3(0.18, 0.05, 0.12), iron)
		"rod":
			# Line hanging from the tip.
			var line: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.006
			cm.bottom_radius = 0.006
			cm.height = 1.6
			line.mesh = cm
			var lm: StandardMaterial3D = StandardMaterial3D.new()
			lm.albedo_color = Color("e8e8e8")
			line.material_override = lm
			line.top_level = true
			line.name = "Line"
			tool_node.add_child(line)

func _tool_box(pos: Vector3, size: Vector3, m: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tool_node.add_child(mi)

func update_line() -> void:
	## Keep a fishing line hanging straight down from the rod tip.
	if tool_node == null or tool_kind != "rod":
		return
	var line: Node3D = tool_node.get_node_or_null("Line")
	if line:
		var tip: Vector3 = sword.global_transform * Vector3(0, 2.1, 0)
		line.global_transform = Transform3D(Basis.IDENTITY, tip + Vector3.DOWN * 0.8)

# ---------------------------------------------------------------- shield (hero)
## A heater shield on the left forearm. shield_mode: "arm" (carried), "guard"
## (raised in front while guarding), "back" (sword sheathed), "surf" (under the feet).
var shield: Node3D
var shield_mode: String = "arm"
var shield_guard: float = 0.0

func add_shield(emblem: Color) -> void:
	shield = Node3D.new()
	shield.name = "Shield"
	add_child(shield)
	var k: float = height / 1.8
	var enamel: StandardMaterial3D = StandardMaterial3D.new()
	enamel.albedo_color = Color("1d3f73")
	enamel.metallic = 0.45
	enamel.roughness = 0.35
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color("d8b45a")
	gold.metallic = 0.85
	gold.roughness = 0.3
	var crest: StandardMaterial3D = StandardMaterial3D.new()
	crest.albedo_color = emblem.lerp(Color.WHITE, 0.35)
	crest.emission_enabled = true
	crest.emission = emblem
	crest.emission_energy_multiplier = 0.6
	var outline: PackedVector2Array = heater_outline(0.29 * k, 0.38 * k)
	shield.add_child(plate(outline, 0.045 * k, 0.05 * k, gold, 0.0))
	shield.add_child(plate(scaled_outline(outline, 0.86), 0.05 * k, 0.045 * k, enamel, 0.012 * k))
	# crest: a tall diamond with a cross bar
	var dia: PackedVector2Array = PackedVector2Array([Vector2(0, 0.2 * k), Vector2(0.075 * k, 0.02 * k), Vector2(0, -0.2 * k), Vector2(-0.075 * k, 0.02 * k)])
	shield.add_child(plate(dia, 0.01 * k, 0.04 * k, crest, 0.045 * k))
	var bar: PackedVector2Array = PackedVector2Array([Vector2(-0.16 * k, 0.07 * k), Vector2(0.16 * k, 0.07 * k), Vector2(0.16 * k, 0.03 * k), Vector2(-0.16 * k, 0.03 * k)])
	shield.add_child(plate(bar, 0.01 * k, 0.04 * k, gold, 0.044 * k))

static func heater_outline(hw: float, hh: float) -> PackedVector2Array:
	## Flat top with rounded shoulders, sides curving down to a point.
	var pts: PackedVector2Array = []
	var n: int = 10
	for i in n + 1:
		var u: float = float(i) / n
		pts.append(Vector2(lerpf(-hw * 0.82, hw * 0.82, u), hh + sin(u * PI) * hh * 0.06))
	for i in range(1, n + 1):
		var u: float = float(i) / n
		var y: float = lerpf(hh * 0.9, -hh, u)
		var x: float = hw * cos(u * PI * 0.5) * (1.0 - 0.15 * u)
		pts.append(Vector2(x, y))
	for i in range(n - 1, 0, -1):
		var u: float = float(i) / n
		var y: float = lerpf(hh * 0.9, -hh, u)
		var x: float = hw * cos(u * PI * 0.5) * (1.0 - 0.15 * u)
		pts.append(Vector2(-x, y))
	return pts

static func scaled_outline(p: PackedVector2Array, s: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for v: Vector2 in p:
		out.append(v * s)
	return out

func plate(outline: PackedVector2Array, thick: float, bulge: float, m: Material, z0: float) -> MeshInstance3D:
	## Extrude a 2D outline into a slightly domed plate (front faces +Z).
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 0.001
	for v: Vector2 in outline:
		w = maxf(w, absf(v.x))
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var front: Array = []
	var back: Array = []
	for v: Vector2 in outline:
		var dome: float = bulge * (1.0 - pow(v.x / (w * 1.05), 2.0))
		front.append(Vector3(v.x, v.y, z0 + thick * 0.5 + dome))
		back.append(Vector3(v.x, v.y, z0 - thick * 0.5 + dome))
	for i in range(0, tris.size(), 3):
		st.add_vertex(front[tris[i]])
		st.add_vertex(front[tris[i + 2]])
		st.add_vertex(front[tris[i + 1]])
		st.add_vertex(back[tris[i]])
		st.add_vertex(back[tris[i + 1]])
		st.add_vertex(back[tris[i + 2]])
	var n: int = outline.size()
	for i in n:
		var j: int = (i + 1) % n
		st.add_vertex(front[i])
		st.add_vertex(back[i])
		st.add_vertex(front[j])
		st.add_vertex(front[j])
		st.add_vertex(back[i])
		st.add_vertex(back[j])
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	if m is StandardMaterial3D:
		(m as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if phone_mode() else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

func place_shield(dt: float) -> void:
	if shield == null or not ready_xform:
		return
	var k: float = height / 1.8
	var fwd: Vector3 = Vector3(0, 0, -1)
	var left: Vector3 = Vector3(-1, 0, 0)
	shield_guard = move_toward(shield_guard, 1.0 if shield_mode == "guard" else 0.0, dt * 9.0)
	match shield_mode:
		"surf":
			shield.transform = Transform3D(Basis(Vector3(1, 0, 0), fwd, Vector3.UP), Vector3(0, 0.05, 0))
			return
		"back":
			var rs: Vector3 = to_rig * sk.get_bone_global_pose(idx["R_Upperarm"]).origin
			var ls: Vector3 = to_rig * sk.get_bone_global_pose(idx["L_Upperarm"]).origin
			var mid: Vector3 = (rs + ls) * 0.5 + Vector3(0, -0.28 * k, 0) - fwd * 0.2 * k
			shield.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, -fwd), mid)
			return
	var fore: Vector3 = to_rig * sk.get_bone_global_pose(idx["L_Forearm"]).origin
	var hand: Vector3 = to_rig * sk.get_bone_global_pose(idx["L_Hand"]).origin
	var a: Vector3 = (hand - fore).normalized()
	var n0: Vector3 = left.lerp(fwd, shield_guard).normalized()
	var n: Vector3 = n0 - a * a.dot(n0)
	if n.length() < 0.1:
		n = fwd
	n = n.normalized()
	var side: Vector3 = a.cross(n).normalized()
	shield.transform = Transform3D(Basis(side, a, n), fore.lerp(hand, 0.55) + n * 0.07 * k)

func shield_facing() -> Vector3:
	## World direction the shield's face points.
	return shield.global_transform.basis.z.normalized() if shield else Vector3.ZERO
