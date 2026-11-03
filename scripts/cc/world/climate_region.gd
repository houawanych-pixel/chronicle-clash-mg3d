extends Node3D
## An area with its own climate (a flat rectangle on the ground, size in x/z).

@export var profile: Resource
@export var size: Vector2 = Vector2(20, 20)

func _ready() -> void:
	add_to_group("cc_climate")

func contains(p: Vector3) -> bool:
	var d: Vector3 = p - global_position
	return absf(d.x) <= size.x * 0.5 and absf(d.z) <= size.y * 0.5
