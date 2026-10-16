extends RefCounted
## A place in the village where one villager can do one thing: chop a tree,
## mine a rock, fish off the dock, tend a field, mind a stall, sit on a bench,
## or go through a door. Only one villager may hold a spot at a time.

var id: String
var kind: String         # tree, rock, fish, field, stall, seat, door, drop
var pos: Vector3         # where the villager stands
var look: Vector3        # what they face while there
var tool: String = "none"
var occupant: Node = null

func _init(spot_id: String, spot_kind: String, at: Vector3, face: Vector3, tool_kind: String = "none") -> void:
	id = spot_id
	kind = spot_kind
	pos = at
	look = face
	tool = tool_kind

func is_free_for(v: Node) -> bool:
	return occupant == null or occupant == v or not is_instance_valid(occupant)

func claim(v: Node) -> bool:
	if not is_free_for(v):
		return false
	occupant = v
	return true

func release(v: Node) -> void:
	if occupant == v:
		occupant = null
