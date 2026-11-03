extends RefCounted
## Small helpers for the CC data files.

static func load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CC data missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("CC data is not an object: " + path)
		return {}
	var d: Dictionary = parsed
	d.erase("_note")
	return d
