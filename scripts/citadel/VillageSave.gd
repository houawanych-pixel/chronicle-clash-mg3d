extends RefCounted
## Village save file. On the web, user:// is the browser's own storage
## (IndexedDB), so progress stays on that phone/browser.
##
## Format (version 1):
## {"version": 1, "clock": minutes since day 1 00:00, "block": "square",
##  "blocks": {"square": {"saved_clock": minutes,
##                        "villagers": {"sq_bram": {...Villager.to_dict()}}}}}
## Unknown keys are ignored and missing keys fall back to defaults, so older
## saves keep loading when fields are added.
const PATH: String = "user://village_save.json"
const VERSION: int = 1

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) > VERSION:
		# A newer game wrote this; don't risk misreading it.
		return {}
	return d

static func save_data(d: Dictionary) -> bool:
	d["version"] = VERSION
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
