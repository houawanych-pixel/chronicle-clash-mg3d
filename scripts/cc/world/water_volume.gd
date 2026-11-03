extends Node3D
## A pond: a box of water (top at the node's y, depth down). Frost Pillars grow from its top.

@export var size: Vector3 = Vector3(10, 2, 10)

func _ready() -> void:
	add_to_group("cc_water")
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	mi.mesh = pm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.4, 0.55, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	mi.material_override = m
	add_child(mi)

func contains(p: Vector3) -> bool:
	var d: Vector3 = p - global_position
	return absf(d.x) <= size.x * 0.5 and absf(d.z) <= size.z * 0.5 and d.y <= 0.3 and d.y >= -size.y

func surface_y() -> float:
	return global_position.y
