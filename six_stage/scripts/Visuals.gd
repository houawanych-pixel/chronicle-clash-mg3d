extends RefCounted
static var mats: Dictionary = {}
static func mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key: String = str(color)+str(glow)
	if mats.has(key): return mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission_enabled = glow > 0
	m.emission = color
	m.emission_energy_multiplier = glow
	mats[key] = m
	return m
static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
	n.position = pos
	return n
static func merged(parent: Node3D, parts: Array, material: Material) -> void:
	if parts.is_empty(): return
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var unit: BoxMesh = BoxMesh.new()
	for part: Array in parts:
		unit.size = part[1]
		var arrays: Array = unit.get_mesh_arrays()
		var base: int = verts.size()
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]: verts.append(v+part[0])
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		for i: int in arrays[Mesh.ARRAY_INDEX]: indices.append(base+i)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts; out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_TEX_UV] = uvs; out[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,out)
	var n: MeshInstance3D = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = material
	parent.add_child(n)
static func solid(parent: Node3D, pos: Vector3, size: Vector3, color: Color, grid: bool = true, moving: bool = false) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cube: BoxShape3D = BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	body.set_meta("size",size)
	body.set_meta("climbable",true)
	box(body,Vector3.ZERO,size,mat(color))
	if grid:
		# Grid lines are merged into one mesh per material. Separate MeshInstances
		# (1,100+ in Build 04) stopped the 3D view drawing in web browsers.
		var line_parts: Array = []
		var edge_parts: Array = []
		var sx: float = size.x/2
		var sy: float = size.y/2
		var sz: float = size.z/2
		for x in range(ceili(-sx),ceili(sx)):
			line_parts.append([Vector3(x,sy+.012,0),Vector3(.018,.015,size.z)])
			line_parts.append([Vector3(x,0,sz+.012),Vector3(.018,size.y,.015)])
			line_parts.append([Vector3(x,0,-sz-.012),Vector3(.018,size.y,.015)])
		for z in range(ceili(-sz),ceili(sz)):
			line_parts.append([Vector3(0,sy+.013,z),Vector3(size.x,.015,.018)])
			line_parts.append([Vector3(sx+.012,0,z),Vector3(.015,size.y,.018)])
			line_parts.append([Vector3(-sx-.012,0,z),Vector3(.015,size.y,.018)])
		for y in range(ceili(-sy),ceili(sy)):
			line_parts.append([Vector3(0,y,sz+.014),Vector3(size.x,.018,.015)])
			line_parts.append([Vector3(0,y,-sz-.014),Vector3(size.x,.018,.015)])
			line_parts.append([Vector3(sx+.014,y,0),Vector3(.015,.018,size.z)])
			line_parts.append([Vector3(-sx-.014,y,0),Vector3(.015,.018,size.z)])
		for z: float in [-sz,sz]: edge_parts.append([Vector3(0,sy+.025,z),Vector3(size.x,.035,.035)])
		for x: float in [-sx,sx]: edge_parts.append([Vector3(x,sy+.025,0),Vector3(.035,.035,size.z)])
		merged(body,line_parts,mat(Color("477487"),0.12))
		merged(body,edge_parts,mat(Color("57cad8"),0.5))
	return body
static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var n: MeshInstance3D = MeshInstance3D.new()
	var m: TorusMesh = TorusMesh.new()
	m.inner_radius = maxf(.01,radius-.045)
	m.outer_radius = radius+.045
	m.rings = 24
	m.ring_segments = 6
	n.mesh = m
	n.material_override = mat(color,.6)
	parent.add_child(n)
	n.position = pos
	return n
static func line(parent: Node3D, a: Vector3, b: Vector3, color: Color, width: float = .025) -> MeshInstance3D:
	var length: float = a.distance_to(b)
	var n: MeshInstance3D = box(parent,(a+b)*.5,Vector3(width,width,maxf(.01,length)),mat(color,.8))
	if length > .001: n.look_at(b,Vector3.UP if absf((b-a).normalized().y)<.99 else Vector3.RIGHT)
	return n
static func label(parent: Node3D, pos: Vector3, value: String, color: Color = Color("a3e6f1"), size: int = 40) -> Label3D:
	var n: Label3D = Label3D.new()
	n.text = value
	n.font = preload("res://assets/ui_bold.ttf")
	n.font_size = size
	n.pixel_size = .012
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = color
	n.outline_size = 5
	parent.add_child(n)
	n.position = pos
	return n
