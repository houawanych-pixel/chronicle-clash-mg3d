extends Node3D
## A patch of grass for the fire system: nx x nz cells of fuel. Draws blades (green -> black
## when burnt) and flames on burning cells.

@export var size: Vector2 = Vector2(20, 20)
@export var material: Resource      # chem_material.gd (grass)

var nx: int = 0
var nz: int = 0
var cell: float = 1.0
var fuel := PackedFloat32Array()
var state := PackedByteArray()      # 0 fresh, 1 burning, 2 burnt
var dirty: bool = true
var blades: MultiMeshInstance3D
var flames: MultiMeshInstance3D

func _ready() -> void:
	if material == null:
		material = load("res://data/cc/chem/grass.tres")
	cell = float(ChemistryService.tuning.cell_size)
	nx = int(size.x / cell)
	nz = int(size.y / cell)
	fuel.resize(nx * nz)
	fuel.fill(float(material.fuel))
	state.resize(nx * nz)
	state.fill(0)
	build_visuals()
	ChemistryService.register(self)

func _exit_tree() -> void:
	ChemistryService.unregister(self)

func cell_center(c: int) -> Vector3:
	@warning_ignore("integer_division")
	return global_position + Vector3((c % nx + 0.5) * cell - size.x * 0.5, 0, (c / nx + 0.5) * cell - size.y * 0.5)

func cells_within(p: Vector3, r: float) -> Array[int]:
	var out: Array[int] = []
	var lp: Vector3 = p - global_position
	var x0: int = clampi(floori((lp.x - r + size.x * 0.5) / cell), 0, nx - 1)
	var x1: int = clampi(floori((lp.x + r + size.x * 0.5) / cell), 0, nx - 1)
	var z0: int = clampi(floori((lp.z - r + size.y * 0.5) / cell), 0, nz - 1)
	var z1: int = clampi(floori((lp.z + r + size.y * 0.5) / cell), 0, nz - 1)
	if lp.x + r < -size.x * 0.5 or lp.x - r > size.x * 0.5 or lp.z + r < -size.y * 0.5 or lp.z - r > size.y * 0.5:
		return out
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var c: int = z * nx + x
			var cc: Vector3 = cell_center(c)
			if Vector2(cc.x - p.x, cc.z - p.z).length() <= r:
				out.append(c)
	return out

func count_state(s: int) -> int:
	var n: int = 0
	for c in nx * nz:
		if state[c] == s:
			n += 1
	return n

func build_visuals() -> void:
	var blade: QuadMesh = QuadMesh.new()
	blade.size = Vector2(0.9, 0.55)
	blade.center_offset = Vector3(0, 0.27, 0)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.roughness = 0.9
	blade.material = gm
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = nx * nz * 2
	mm.mesh = blade
	blades = MultiMeshInstance3D.new()
	blades.multimesh = mm
	blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blades)
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 3
	for c in nx * nz:
		for k in 2:
			var lp: Vector3 = cell_center(c) - global_position + Vector3(r.randf_range(-0.3, 0.3), 0, r.randf_range(-0.3, 0.3))
			mm.set_instance_transform(c * 2 + k, Transform3D(Basis(Vector3.UP, r.randf() * PI + k * PI * 0.5), lp))
	var flame: QuadMesh = QuadMesh.new()
	flame.size = Vector2(0.7, 1.1)
	flame.center_offset = Vector3(0, 0.5, 0)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.vertex_color_use_as_albedo = true
	flame.material = fm
	var fmm: MultiMesh = MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.instance_count = nx * nz
	fmm.visible_instance_count = 0
	fmm.mesh = flame
	flames = MultiMeshInstance3D.new()
	flames.multimesh = fmm
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flames)

func _process(_dt: float) -> void:
	if not dirty:
		return
	dirty = false
	var mm: MultiMesh = blades.multimesh
	var fmm: MultiMesh = flames.multimesh
	var nf: int = 0
	var t: float = Time.get_ticks_msec() * 0.001
	for c in nx * nz:
		var col: Color = Color("6fae3e").lerp(Color("4c8a2c"), float((c * 7) % 5) / 5.0)
		if state[c] == 2:
			col = Color("2a2522")
		elif state[c] == 1:
			col = Color("8a5a24")
		elif fuel[c] < float(material.fuel):
			col = col.darkened(0.35)
		mm.set_instance_color(c * 2, col)
		mm.set_instance_color(c * 2 + 1, col)
		if state[c] == 1:
			var lp: Vector3 = cell_center(c) - global_position
			fmm.set_instance_transform(nf, Transform3D(Basis().scaled(Vector3.ONE * (0.8 + 0.4 * sin(t * 9.0 + c))), lp))
			fmm.set_instance_color(nf, Color(1.0, 0.55 + 0.2 * sin(t * 7.0 + c), 0.15, 0.9))
			nf += 1
	fmm.visible_instance_count = nf
	if nf > 0:
		dirty = true     # keep flickering
