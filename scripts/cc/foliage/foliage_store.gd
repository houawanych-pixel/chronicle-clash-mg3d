extends RefCounted
## Foliage state kept between visits (and in the save file): per world, the burn states and vine
## lengths with their world-clock timestamps. A world that is built again restores it and the
## season tick catches up on the time that passed while it was not loaded.

static var worlds: Dictionary = {}     # world id -> FoliageManager.snapshot()
static var _registered: bool = false

static func register_save() -> void:
	if _registered:
		return
	_registered = true
	var me: Script = load("res://scripts/cc/foliage/foliage_store.gd")
	SaveService.register("foliage", Callable(me, "to_save"), Callable(me, "from_save"))

static func keep(world_id: String, snap: Dictionary) -> void:
	worlds[world_id] = snap

static func get_snapshot(world_id: String) -> Dictionary:
	return worlds.get(world_id, {})

static func to_save() -> Dictionary:
	return worlds.duplicate(true)

static func from_save(d: Variant) -> void:
	if d is Dictionary:
		worlds = (d as Dictionary).duplicate(true)
