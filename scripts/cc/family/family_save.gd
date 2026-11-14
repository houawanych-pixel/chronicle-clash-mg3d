extends RefCounted
## Local family save (offline play and the cache of the last server state).
## Kept in its own file so the existing village save (VillageSave.gd,
## user://village_save.json) is never rewritten by this module.
##
## Schema 1:
## {"schema": 1, "world_id": "cc_village", "rev": int,
##  "npcs": {npc_id: record}, "families": {family_id: record},
##  "relationships": {"a|b": record}, "pregnancies": {pregnancy_id: record},
##  "applied": {event_id: rev}, "applied_order": [event_id, ...]}
##
## Migration: a missing file (schema 0, every save made before this module)
## is seeded from the hand-written village cast. Fields added later are
## filled from family_profile.gd defaults on load, so older schema-1 files
## keep loading. A file from a newer schema is not touched.
const Profile = preload("res://scripts/cc/family/family_profile.gd")
const PATH: String = "user://family_save.json"

static func load_state(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("schema", 0)) > Profile.SCHEMA:
		return {"_newer": true}
	return migrate(d)

## Fill in anything an older file is missing; JSON numbers come back as
## floats, so ids and timestamps are turned back into ints here.
static func migrate(d: Dictionary) -> Dictionary:
	var base: Dictionary = Profile.empty_state()
	base.merge(d, true)
	base.schema = Profile.SCHEMA
	base.rev = int(base.rev)
	for id: String in base.npcs:
		var full: Dictionary = Profile.new_npc(id, id)
		full.merge(base.npcs[id], true)
		for k: String in ["birth_timestamp", "died_at", "last_birth_at"]:
			full[k] = int(full[k])
		for tr: Dictionary in full.stage_log:
			tr["at"] = int(tr.at)
		for m: Dictionary in full.memories:
			m["at"] = int(m.at)
		base.npcs[id] = full
	for key: String in base.relationships:
		var rel: Dictionary = Profile.new_relationship(str(base.relationships[key].get("a", "")), str(base.relationships[key].get("b", "")))
		rel.merge(base.relationships[key], true)
		rel.since = int(rel.since)
		rel.last_visit_at = int(rel.last_visit_at)
		base.relationships[key] = rel
	for pid: String in base.pregnancies:
		var p: Dictionary = base.pregnancies[pid]
		for k: String in ["conceived_at", "due_at"]:
			p[k] = int(p[k])
	for id: String in base.applied:
		base.applied[id] = int(base.applied[id])
	return base

static func save_state(state: Dictionary, path: String = PATH) -> bool:
	state["schema"] = Profile.SCHEMA
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	# Write-then-rename so a crash mid-save never leaves a half file.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

static func clear(path: String = PATH) -> void:
	for p: String in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

## Register the hand-written cast as established adults (or, for Pip, as the
## child he is written as). Only relationships the village text already
## states are kept: Ada and Rolf are married. Nothing else is invented:
## Pip "lives with Ada" but is not written as anyone's son, so he gets no
## parents; Finn's crush on Lia stays a note, not a relationship.
static func seed_events(blocks: Dictionary, at: int) -> Array:
	var evs: Array = []
	for block: String in blocks:
		for d: Dictionary in blocks[block].villagers:
			var rec: Dictionary = {
				"npc_id": d.id,
				"name": d.name,
				"current_job": d.job,
				"personality": d.get("persona", ""),
				"sex": "f" if d.get("female", false) else "m",
				"can_carry": d.get("female", false),
				"home_id": "%s/%s" % [block, d.home],
				"location": block,
				"established": true,
				"age_locked": true,
				"life_stage": "child" if d.id == "ml_pip" else "adult",
				"appearance_traits": {"tint": (d.tint as Color).to_html(false) if d.has("tint") else "", "model": int(d.get("model", 0)), "height": float(d.get("height", 1.75))},
			}
			evs.append({"id": "seed:" + str(d.id), "type": "register_npc", "at": at, "args": {"npc": rec}})
	return evs

## The one established couple. Applied straight to state (not as a consent
## event) because their marriage is already written into the village.
static func seed_relationships(state: Dictionary, at: int) -> void:
	if not (state.npcs.has("ml_ada") and state.npcs.has("ml_rolf")):
		return
	var rel: Dictionary = Profile.new_relationship("ml_ada", "ml_rolf")
	rel.kind = "married"
	rel.consent = {"ml_ada": true, "ml_rolf": true}
	rel.since = at
	rel.established = true
	rel.notes = ["Married in the village text (Ada's and Rolf's personas)."]
	state.relationships[rel.key] = rel
	var fid: String = "fam_ml_ada__ml_rolf"
	var fam: Dictionary = Profile.new_family(fid, ["ml_ada", "ml_rolf"], "mill/home_ada")
	fam.partner_relationships = [rel.key]
	fam.family_relationship_history = [{"at": at, "kind": "established", "ids": ["ml_ada", "ml_rolf"]}]
	state.families[fid] = fam
	state.npcs.ml_ada.family_id = fid
	state.npcs.ml_rolf.family_id = fid
	if state.npcs.has("sq_finn"):
		var crush: Dictionary = Profile.new_relationship("sq_finn", "sq_lia")
		crush.notes = ["Finn is sweet on Lia but has not said so (Finn's persona). Not a partnership."]
		crush.established = true
		state.relationships[crush.key] = crush
