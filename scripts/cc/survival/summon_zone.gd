extends Node3D
## A tagged circle on the map ("interior", "sanctum", "deep_water" ...). The bike's summon
## checks these against its deny list.

@export var tag: String = "sanctum"
@export var radius: float = 6.0

func _ready() -> void:
	add_to_group("cc_zone")
