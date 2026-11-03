extends Node3D
## The weapon's hitbox. Its Area3D is switched on only by the clip's hit_start track and off
## by hit_end, so swings can never hit outside their active frames. While on, every physics
## frame it reports each hurtbox it overlaps (once per swing) to its owner.

signal touched(hurtbox: Area3D)

const HURTBOX_LAYER: int = 16

var area: Area3D
var shape: SphereShape3D
var live: bool = false
var already: Array = []

func _ready() -> void:
	area = Area3D.new()
	area.name = "Hitbox"
	area.collision_layer = 0
	area.collision_mask = HURTBOX_LAYER
	area.monitorable = false
	area.monitoring = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	shape = SphereShape3D.new()
	shape.radius = 0.9
	cs.shape = shape
	area.add_child(cs)
	add_child(area)

## Place and size it for a move (in the owner's facing frame: forward is -Z).
func configure(reach: float, radius: float, height: float) -> void:
	area.position = Vector3(0, height, -reach)
	shape.radius = radius

func open() -> void:
	live = true
	already.clear()
	area.monitoring = true

func close() -> void:
	live = false
	area.monitoring = false

func _physics_process(_dt: float) -> void:
	if not live:
		return
	for a: Area3D in area.get_overlapping_areas():
		if a in already:
			continue
		already.append(a)
		touched.emit(a)
