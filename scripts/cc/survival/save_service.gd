extends Node
## Autoload SaveService: writes the survival state (inventory, clock) to user://cc_save.json.
## Other systems can add their own blocks with register(key, save_fn, load_fn).

const PATH: String = "user://cc_save.json"

var _parts: Dictionary = {}

func _ready() -> void:
	register("inventory", InventoryService.to_save, InventoryService.from_save)
	register("clock", WorldClock.to_save, WorldClock.from_save)

func register(key: String, save_fn: Callable, load_fn: Callable) -> void:
	_parts[key] = [save_fn, load_fn]

func save_game(path: String = PATH) -> bool:
	var out: Dictionary = {"version": 1}
	for k: String in _parts:
		out[k] = (_parts[k][0] as Callable).call()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(out))
	return true

func load_game(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed
	for k: String in _parts:
		if d.has(k):
			(_parts[k][1] as Callable).call(d[k])
	return true
