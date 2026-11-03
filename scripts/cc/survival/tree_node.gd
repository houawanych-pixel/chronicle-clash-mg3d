extends StaticBody3D
## CC tree you can chop down. Hits from a tool do power x chop_mult[kind] damage (blunt tools
## bounce off). At zero the trunk comes down: the stump stays, a physics log tips over and
## rolls, and the wood goes straight into the inventory.

signal chopped(damage: float, hp_left: float)
signal bounced(tool_kind: String)
signal felled(log: RigidBody3D, wood: int)

@export var tree: Resource            # tree_resource.gd
@export var seed_value: int = 0

var hp: float = 0.0
var is_felled: bool = false
var log_body: RigidBody3D
var trunk_mesh: MeshInstance3D
var canopy: Node3D
var stump_mesh: MeshInstance3D
var shape: CollisionShape3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var shake_t: float = 0.0
var bark_mat: StandardMaterial3D
var leaf_mat: StandardMaterial3D
var cut_mat: StandardMaterial3D

func _ready() -> void:
	if tree == null:
		tree = load("res://data/cc/trees/oak.tres")
	rng.seed = seed_value if seed_value != 0 else hash(global_position)
	hp = float(tree.hp)
	add_to_group("cc_tree")
	build()

func build() -> void:
	bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = tree.bark_color
	bark_mat.roughness = 0.95
	leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = tree.leaf_color
	leaf_mat.roughness = 0.9
	cut_mat = StandardMaterial3D.new()
	cut_mat.albedo_color = Color("d9b98a")
	var r: float = tree.trunk_radius
	var sh: float = tree.stump_height
	stump_mesh = MeshInstance3D.new()
	stump_mesh.mesh = trunk_piece(r * 1.15, r * 1.05, sh)
	stump_mesh.position.y = sh * 0.5
	stump_mesh.material_override = bark_mat
	add_child(stump_mesh)
	trunk_mesh = MeshInstance3D.new()
	trunk_mesh.mesh = trunk_piece(r * 1.05, r * 0.6, tree.trunk_height - sh)
	trunk_mesh.material_override = bark_mat
	trunk_mesh.position.y = sh + (tree.trunk_height - sh) * 0.5
	add_child(trunk_mesh)
	canopy = make_canopy()
	canopy.position.y = tree.trunk_height
	add_child(canopy)
	shape = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = r
	cyl.height = tree.trunk_height
	shape.shape = cyl
	shape.position.y = tree.trunk_height * 0.5
	add_child(shape)

func trunk_piece(bottom: float, top: float, h: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = h
	m.radial_segments = 9
	m.rings = 2
	return m

## A rounded crown of overlapping, squashed blobs (lean a little for a hand-made look).
func make_canopy() -> Node3D:
	var n: Node3D = Node3D.new()
	var cr: float = tree.canopy_radius
	var count: int = 4 + rng.randi_range(0, 2)
	for i in count:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		var s: float = cr * rng.randf_range(0.55, 0.8)
		sm.radius = s
		sm.height = s * rng.randf_range(1.2, 1.6)
		sm.radial_segments = 10
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = leaf_mat
		var a: float = i * TAU / count + rng.randf() * 0.6
		mi.position = Vector3(cos(a) * cr * 0.45, rng.randf_range(-0.2, 0.5) * cr, sin(a) * cr * 0.45)
		n.add_child(mi)
	var top: MeshInstance3D = MeshInstance3D.new()
	var ts: SphereMesh = SphereMesh.new()
	ts.radius = cr * 0.65
	ts.height = cr * 1.0
	top.mesh = ts
	top.material_override = leaf_mat
	top.position.y = cr * 0.55
	n.add_child(top)
	return n

## Damage this tool would do to this tree (0 = it can't cut it).
func chop_damage(tool: Resource) -> float:
	var mult: float = float(tree.chop_mult.get(tool.kind, 0.0))
	return float(tool.power) * mult

## A hit from a tool, swung from from_pos. Returns the damage done.
func hit(tool: Resource, from_pos: Vector3) -> float:
	if is_felled:
		return 0.0
	var dmg: float = chop_damage(tool)
	if dmg <= 0.0:
		shake_t = 0.15
		bounced.emit(str(tool.kind))
		return 0.0
	hp -= dmg
	shake_t = 0.3
	chopped.emit(dmg, maxf(hp, 0.0))
	if hp <= 0.0:
		fell(from_pos)
	return dmg

func fell(from_pos: Vector3) -> void:
	is_felled = true
	hp = 0.0
	trunk_mesh.visible = false
	canopy.visible = false
	var stump_shape: CylinderShape3D = CylinderShape3D.new()
	stump_shape.radius = tree.trunk_radius * 1.1
	stump_shape.height = tree.stump_height
	shape.shape = stump_shape
	shape.position.y = tree.stump_height * 0.5
	var cut: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = tree.trunk_radius * 1.02
	cm.bottom_radius = tree.trunk_radius * 1.02
	cm.height = 0.02
	cut.mesh = cm
	cut.material_override = cut_mat
	cut.position.y = tree.stump_height + 0.01
	add_child(cut)
	log_body = spawn_log(from_pos)
	var wood: int = rng.randi_range(int(tree.wood_min), int(tree.wood_max))
	var got: int = InventoryService.add(str(tree.wood_item), wood)
	felled.emit(log_body, got)

func spawn_log(from_pos: Vector3) -> RigidBody3D:
	var len: float = tree.trunk_height - tree.stump_height
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "Log"
	body.mass = tree.log_mass
	body.add_to_group("cc_log")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = tree.trunk_radius
	cyl.height = len
	cs.shape = cyl
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = trunk_piece(tree.trunk_radius, tree.trunk_radius * 0.6, len)
	mi.material_override = bark_mat
	body.add_child(mi)
	var crown: Node3D = make_canopy()
	crown.position.y = len * 0.5
	crown.name = "Crown"
	body.add_child(crown)
	get_parent().add_child(body)
	body.global_position = global_position + Vector3.UP * (tree.stump_height + len * 0.5 + 0.03)
	# it falls away from whoever cut it
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var axis: Vector3 = Vector3.UP.cross(away).normalized()
	body.angular_velocity = axis * 1.1
	body.linear_velocity = away * 0.8
	# the crown breaks off and shrinks away after the fall
	var tw: Tween = body.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(crown, "scale", Vector3.ONE * 0.01, 0.8)
	tw.tween_callback(crown.queue_free)
	return body

func _process(dt: float) -> void:
	if shake_t > 0.0:
		shake_t -= dt
		var k: float = shake_t * 0.08
		canopy.rotation = Vector3(sin(shake_t * 60.0) * k, 0, cos(shake_t * 50.0) * k)
