extends RefCounted
## Record shapes for the family module. Records are plain Dictionaries so the
## same JSON travels between the game, the local save and the server.
## Keys are stable ids (npc_id, family_id), never names.

const SCHEMA: int = 1

## FNV-1a 32-bit over UTF-8. Deterministic and identical in the server
## (server/family/rules.js) so both sides roll the same dice for one event.
static func fnv(s: String) -> int:
	var h: int = 2166136261
	for b: int in s.to_utf8_buffer():
		h = h ^ b
		h = (h * 16777619) & 0xffffffff
	return h

static func unit(s: String) -> float:
	return float(fnv(s)) / 4294967296.0

static func pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func new_npc(npc_id: String, display_name: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"name": display_name,
		"birth_timestamp": -1,          # unix seconds; -1 = established cast, age unknown
		"life_stage": "adult",
		"parent_ids": [],
		"family_id": "",
		"personality": "",
		"appearance_traits": {},
		"current_job": "",
		"current_activity": "",
		"alive": true,
		"health_state": "well",
		"memory_summary": "",
		"memories": [],
		"stage_log": [],
		"sex": "",
		"can_carry": false,
		"home_id": "",                  # "<block>/<door id>", e.g. "mill/home_ada"
		"location": "",                 # block id
		"established": false,           # true for the hand-written village cast
		"age_locked": false,            # established cast keeps its written age
		"recruited_by": "",
		"died_at": -1,
		"last_birth_at": -1,
	}

static func new_family(family_id: String, parent_ids: Array, home_id: String) -> Dictionary:
	return {
		"family_id": family_id,
		"parent_ids": parent_ids.duplicate(),
		"child_ids": [],
		"partner_relationships": [],
		"home_id": home_id,
		"family_relationship_history": [],
	}

static func new_relationship(a: String, b: String) -> Dictionary:
	return {
		"key": pair_key(a, b),
		"a": a if a < b else b,
		"b": b if a < b else a,
		"kind": "acquaintance",         # acquaintance, proposed, partners, married, ended, widowed
		"consent": {},                  # npc_id -> true once that person agreed
		"since": -1,
		"last_visit_at": -1,
		"established": false,
		"notes": [],
	}

static func empty_state() -> Dictionary:
	return {
		"schema": SCHEMA,
		"world_id": "cc_village",
		"rev": 0,
		"npcs": {},
		"families": {},
		"relationships": {},
		"pregnancies": {},
		"applied": {},
		"applied_order": [],
	}

static func home_block(home_id: String) -> String:
	return home_id.get_slice("/", 0) if home_id.contains("/") else ""

static func home_door(home_id: String) -> String:
	return home_id.get_slice("/", 1) if home_id.contains("/") else home_id
