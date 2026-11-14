extends RefCounted
## Bounded family context for the existing Echo Vision chat (VillageChat.gd +
## web/village_chat.js). The chatbot itself is unchanged; this only adds a
## few short fields to the context it already receives.
##
## The AI never decides anything. It may *propose* one kind of change, a
## memory ("remember"), which validate_proposal() checks before the game
## applies it as an ordinary event. Pregnancy, birth, aging, death, partners,
## jobs and recruitment proposals from the AI are always refused.
const Profile = preload("res://scripts/cc/family/family_profile.gd")
const Growth = preload("res://scripts/cc/family/child_growth.gd")

const ALLOWED_PROPOSALS: Array = ["remember"]
const STAGE_WORDS: Dictionary = {
	"newborn": "a newborn baby", "crawling_infant": "a crawling baby", "early_walker": "a baby taking first steps",
	"toddler": "a toddler", "child": "a child", "adolescent": "a teenager", "adult": "a grown-up",
}

static func names_of(svc: RefCounted, ids: Array) -> String:
	var out: PackedStringArray = PackedStringArray()
	for id: Variant in ids:
		var r: Dictionary = svc.npc(str(id))
		if not r.is_empty():
			out.append(str(r.name) + ("" if bool(r.alive) else " (passed away)"))
	return ", ".join(out)

## Extra fields merged into VillageChat.context(). Every string is capped,
## so the prompt stays small however long the family history grows.
static func context_for(svc: RefCounted, npc_id: String, now: int, location: String, world: String) -> Dictionary:
	var r: Dictionary = svc.npc(npc_id)
	if r.is_empty():
		return {}
	var kids: Array = []
	for c: Dictionary in svc.children_of(npc_id):
		kids.append("%s (%s)" % [c.name, STAGE_WORDS.get(str(c.life_stage), str(c.life_stage))])
	var partner: String = svc.partner_of(npc_id)
	var stage: String = str(r.life_stage)
	var age: int = Growth.age_days(int(r.birth_timestamp), now, svc.cfg)
	return {
		"stage": stage,
		"stage_words": STAGE_WORDS.get(stage, stage),
		"age_days": age,
		"parents": names_of(svc, r.parent_ids).left(120),
		"partner": names_of(svc, [partner]).left(60) if partner != "" else "",
		"children": ", ".join(PackedStringArray(kids)).left(200),
		"activity": str(r.current_activity).left(60),
		"location": location.left(60),
		"world": world.left(160),
		"memories": str(r.memory_summary).left(svc.cfg.memory_summary_chars),
		"can_talk": svc.cfg.stage_index(stage) >= svc.cfg.stage_index(svc.cfg.chat_min_stage),
	}

## Check something the chat proposed. Returns {"ok", "error"?, "event"?}.
## The returned event still goes through FamilyService.apply() (or the
## server), which validates it again.
static func validate_proposal(svc: RefCounted, npc_id: String, prop: Variant, event_id: String, now: int) -> Dictionary:
	if typeof(prop) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_shape"}
	var kind: String = str(prop.get("kind", ""))
	if not (kind in ALLOWED_PROPOSALS):
		return {"ok": false, "error": "not_allowed:" + kind}
	if svc.npc(npc_id).is_empty() or not bool(svc.npc(npc_id).alive):
		return {"ok": false, "error": "unknown_npc"}
	var text: String = str(prop.get("text", "")).replace("\n", " ").strip_edges()
	if text.length() < 3:
		return {"ok": false, "error": "empty"}
	text = text.left(svc.cfg.memory_entry_chars)
	return {"ok": true, "event": {"id": event_id, "type": "remember", "at": now, "args": {"npc_id": npc_id, "text": text}}}

## Simple per-minute budget for chat requests (no continuous AI calls).
class Budget:
	var per_minute: int
	var stamps: Array = []
	func _init(n: int) -> void:
		per_minute = n
	func take(now_s: float) -> bool:
		while not stamps.is_empty() and now_s - float(stamps[0]) >= 60.0:
			stamps.pop_front()
		if stamps.size() >= per_minute:
			return false
		stamps.append(now_s)
		return true
